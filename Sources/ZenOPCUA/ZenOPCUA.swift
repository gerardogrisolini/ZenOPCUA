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

    private let eventLoopGroup: EventLoopGroup
    private let handler = OPCUAHandler()
    private var channel: Channel? = nil

    public var onDataChanged: OPCUADataChanged? = nil
    public var onHandlerRemoved: OPCUAHandlerRemoved? = nil
    public var onErrorCaught: OPCUAErrorCaught? = nil
    
    static var reconnect: Bool = false

    
    public init(
        eventLoopGroup: EventLoopGroup,
        endpoint: String,
        applicationName: String = "ZenOPCUA",
        messageSecurityMode: MessageSecurityMode = .none,
        securityPolicy: SecurityPolicies = .none,
        certificate: String? = nil,
        privateKey: String? = nil
    ) {
        self.eventLoopGroup = eventLoopGroup
        handler.applicationName = applicationName
        OPCUAHandler.endpoint.endpointUrl = endpoint
        OPCUAHandler.messageSecurityMode = messageSecurityMode
        OPCUAHandler.securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicy.uri)
        OPCUAHandler.certificate = certificate
        OPCUAHandler.privateKey = privateKey
    }
    
    private func getHostFromEndpoint() -> (host: String, port: Int) {
        let url = OPCUAHandler.endpoint.endpointUrl
        if let index = url.lastIndex(of: ":") {
            let host = url[url.startIndex..<index]
                .replacingOccurrences(of: "opc.tcp://", with: "")
                //.replacingOccurrences(of: "opc.https://", with: "")
            var port = 0
            
            let part = url[url.index(after: index)...].description
            if let indexEnd = part.firstIndex(of: "/") {
                port = Int(part[part.startIndex..<indexEnd])!
            } else {
                port = Int(part)!
            }
            
            return (host, port)
        }

        return ("", 0)
    }
    
    private func start() -> EventLoopFuture<Void> {
        let server = getHostFromEndpoint()

        let handlers: [ChannelHandler] = [
            MessageToByteHandler(OPCUAFrameEncoder()),
            ByteToMessageHandler(OPCUAFrameDecoder()),
            handler
        ]
        
        return ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_KEEPALIVE), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandlers(handlers)
            }
            .connect(host: server.host, port: server.port)
            .map { channel -> Void in
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

    public func connect(username: String? = nil, password: String? = nil, reconnect: Bool = true) -> EventLoopFuture<Void> {
        ZenOPCUA.reconnect = reconnect
        OPCUAHandler.isAcknowledge = true
        OPCUAHandler.isAcknowledgeSecure = OPCUAHandler.messageSecurityMode != .none
        
        handler.username = username
        handler.password = password
        handler.dataChanged = onDataChanged
        handler.errorCaught = onErrorCaught
        handler.handlerRemoved = {
            if let onHandlerRemoved = self.onHandlerRemoved {
                onHandlerRemoved()
            }
                        
            if ZenOPCUA.reconnect && !OPCUAHandler.isAcknowledge || OPCUAHandler.isAcknowledgeSecure {
                self.stop().whenComplete { _ in
                    self.start().whenComplete { _ in
                        OPCUAHandler.isAcknowledgeSecure = false
                    }
                }
            }
        }
        
        return start().flatMap { () -> EventLoopFuture<Void> in
            if self.handler.promises.index(forKey: 0) == nil {
                self.handler.promises[0] = self.channel!.eventLoop.makePromise()
            }
            return self.handler.promises[0]!.futureResult.map { item -> Void in
                ()
            }
        }
    }
    
    public func disconnect(deleteSubscriptions: Bool = true) -> EventLoopFuture<Void> {
        ZenOPCUA.reconnect = false
        return closeSession(deleteSubscriptions: deleteSubscriptions).flatMap { (_) -> EventLoopFuture<Void> in
            return self.stop()
        }
    }

    private func closeSession(deleteSubscriptions: Bool) -> EventLoopFuture<Promisable> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        if deleteSubscriptions { stopPublish() }
        
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

    public func browse(nodes: [BrowseDescription] = [BrowseDescription()]) -> EventLoopFuture<[BrowseResult]> {
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
            authenticationToken: session.authenticationToken,
            nodesToBrowse: nodes
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [BrowseResult] in
            promise as! [BrowseResult]
        }
    }

    public func read(nodes: [ReadValue]) -> EventLoopFuture<[DataValue]> {
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

    public func write(nodes: [WriteValue]) -> EventLoopFuture<[StatusCodes]> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise(of: Promisable.self)

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = WriteRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            nodesToWrite: nodes
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [StatusCodes] in
            promise as! [StatusCodes]
        }
    }

    public func createSubscription(subscription: Subscription, startPubliscing: Bool = false) -> EventLoopFuture<UInt32> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise(of: Promisable.self)

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = CreateSubscriptionRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            subscription: subscription
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        if startPubliscing {
            self.startPublish(milliseconds: Int64(subscription.requestedPubliscingInterval))
        }

        return handler.promises[requestId]!.futureResult.map { promise -> UInt32 in
            promise as! UInt32
        }
    }
    
    public func createMonitoredItems(subscriptionId: UInt32, itemsToCreate: [MonitoredItemCreateRequest]) -> EventLoopFuture<[MonitoredItemCreateResult]> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise(of: Promisable.self)

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = CreateMonitoredItemsRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            subscriptionId: subscriptionId,
            itemsToCreate: itemsToCreate
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [MonitoredItemCreateResult] in
            promise as! [MonitoredItemCreateResult]
        }
    }
    
    public func deleteSubscriptions(subscriptionIds: [UInt32], stopPubliscing: Bool = false) -> EventLoopFuture<[StatusCodes]> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        if stopPubliscing { stopPublish() }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = channel.eventLoop.makePromise(of: Promisable.self)

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = DeleteSubscriptionsRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            subscriptionIds: subscriptionIds
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        channel.writeAndFlush(frame, promise: nil)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [StatusCodes] in
            promise as! [StatusCodes]
        }
    }
    
    public func publish() -> EventLoopFuture<Void> {
        guard let channel = channel, let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        let requestId = self.handler.nextMessageID()
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = PublishRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)

        return channel.writeAndFlush(frame)
    }
    
    private var publisher: RepeatedTask? = nil

    private func startPublish(milliseconds: Int64) {
        stopPublish()

        guard let channel = channel else { return }

        let time = TimeAmount.milliseconds(milliseconds)
        publisher = channel.eventLoop.scheduleRepeatedAsyncTask(initialDelay: time, delay: time, { task -> EventLoopFuture<Void> in
            self.publish()
        })
    }
    
    private func stopPublish() {
        if let pub = publisher {
            pub.cancel()
            publisher = nil
        }
    }
}

