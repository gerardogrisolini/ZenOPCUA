//
//  ZenOPCUA.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO


enum OPCUAError : Error {
    case connectionError
    case code(_ status: StatusCodes)
    case generic(_ text: String)
}

public class ZenOPCUA {

    public static var host: String = ""
    public static var port: Int = 4842
    public static var username: String? = nil
    public static var password: String? = nil
    
    private let eventLoopGroup: EventLoopGroup
    private var channel: Channel? = nil
    private let handler = OPCUAHandler()
    private var autoreconnect: Bool = false

    public var onMessageReceived: OPCUAMessageReceived? = nil
    public var onHandlerRemoved: OPCUAHandlerRemoved? = nil
    public var onErrorCaught: OPCUAErrorCaught? = nil
    
    public init(host: String, port: Int, reconnect: Bool, eventLoopGroup: EventLoopGroup) {
        ZenOPCUA.host = host
        ZenOPCUA.port = port
        self.autoreconnect = reconnect
        self.eventLoopGroup = eventLoopGroup
    }
    
    private func start() -> EventLoopFuture<Void> {
        
        let handlers: [ChannelHandler] = [
            MessageToByteHandler(OPCUAFrameEncoder()),
            ByteToMessageHandler(OPCUAFrameDecoder()),
            handler
        ]
        
        return ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandlers(handlers)
        }
        .connect(host: ZenOPCUA.host, port: ZenOPCUA.port)
        .map { channel -> () in
            self.channel = channel
        }
    }
    
    private func stop() -> EventLoopFuture<Void> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        
        channel.flush()
        return channel.close(mode: .all).map { () -> () in
            self.channel = nil
        }
    }

    private func send(frame: OPCUAFrame) -> EventLoopFuture<Void> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        
        return channel.writeAndFlush(frame)
    }

    public func reconnect() -> EventLoopFuture<Void> {
        return start().flatMap { () -> EventLoopFuture<Void> in
            let head = OPCUAFrameHead(messageType: .hello, chunkType: .frame)
            let body = Hello(endpointUrl: "opc.tcp://\(ZenOPCUA.host):\(ZenOPCUA.port)")
            return self.send(frame: OPCUAFrame(head: head, body: body.bytes))
        }
    }

    public func connect(username: String? = nil, password: String? = nil) -> EventLoopFuture<Void> {
        ZenOPCUA.username = username
        ZenOPCUA.password = password

        handler.messageReceived = onMessageReceived
        handler.errorCaught = onErrorCaught
        handler.handlerRemoved = {
            if let onHandlerRemoved = self.onHandlerRemoved {
                onHandlerRemoved()
            }
            
            if self.autoreconnect {
                self.stop().whenComplete { _ in
                    self.reconnect().whenComplete { _ in }
                }
            }
        }
        
        return reconnect()
    }
    
    public func disconnect(deleteSubscriptions: Bool = true) -> EventLoopFuture<Void> {
        autoreconnect = false
        return closeSession(deleteSubscriptions: deleteSubscriptions).flatMap { (_) -> EventLoopFuture<Void> in
            return self.stop()
        }
    }

    private func closeSession(deleteSubscriptions: Bool) -> EventLoopFuture<Promisable> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise()

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = CloseSessionRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            deleteSubscriptions: deleteSubscriptions
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult
    }

    public func browse() -> EventLoopFuture<BrowseResult> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise(of: Promisable.self)

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = BrowseRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult.map { promise -> BrowseResult in
            promise as! BrowseResult
        }
    }

    public func read(nodes: [ReadValueId]) -> EventLoopFuture<[DataValue]> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise(of: Promisable.self)

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = ReadRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            nodesToRead: nodes
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [DataValue] in
            promise as! [DataValue]
        }
    }
}

