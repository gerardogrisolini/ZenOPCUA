//
//  ZenOPCUA.swift
//
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO
import NIOConcurrencyHelpers

public enum OPCUAError : Error {
    case connectionError
    case sessionError
    case timeout
    case code(_ status: StatusCodes, reason: String = "")
    case generic(_ text: String)
}

public class ZenOPCUA {

    private let dispatchQueue = DispatchQueue(label: "writer", attributes: .concurrent)
    private let eventLoopGroup: EventLoopGroup
    private let handler = OPCUAHandler()
    private var channel: Channel? = nil
    
    public var onDataChanged: OPCUADataChanged? = nil
    public var onHandlerActivated: OPCUAHandlerChange? = nil
    public var onHandlerRemoved: OPCUAHandlerChange? = nil
    public var onErrorCaught: OPCUAErrorCaught? = nil
    
    static var reconnect: Bool = false
    
    public init(
        eventLoopGroup: EventLoopGroup,
        endpointUrl: String,
        applicationName: String = "ZenOPCUA",
        messageSecurityMode: MessageSecurityMode = .none,
        securityPolicy: SecurityPolicies = .none,
        certificate: String? = nil,
        privateKey: String? = nil
    ) {
        self.eventLoopGroup = eventLoopGroup
        handler.endpointUrl = endpointUrl
        handler.applicationName = applicationName
        handler.certificate = certificate
        handler.privateKey = privateKey
        OPCUAHandler.messageSecurityMode = messageSecurityMode
        OPCUAHandler.securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicy.uri)
    }
    
    private func getHostFromEndpoint() -> (host: String, port: Int) {
        let url = handler.endpointUrl
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
            ByteToMessageHandler(OPCUAFrameDecoder()),
            MessageToByteHandler(OPCUAFrameEncoder()),
            handler
        ]

        return ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_KEEPALIVE), value: 1)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .channelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .channelOption(ChannelOptions.connectTimeout, value: .seconds(5))
            .channelInitializer { channel in
                channel.pipeline.addHandlers(handlers)
            }
            .connect(host: server.host, port: server.port)
            .map { channel -> Void in
                self.channel = channel
            }
            .flatMapError { error -> EventLoopFuture<Void> in
                self.eventLoopGroup.next().makeFailedFuture(error)
            }
    }
    
    private func stop() -> EventLoopFuture<Void> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        handler.resetAll()

        channel.flush()
        return channel.close(mode: .all).map { () -> () in
            self.channel = nil
        }
    }
    
    public func connect(username: String? = nil, password: String? = nil, reconnect: Bool = true, sessionLifetime: UInt32 = 3600000) -> EventLoopFuture<Void> {
        ZenOPCUA.reconnect = reconnect
        OPCUAHandler.isAcknowledge = true
        
        handler.username = username
        handler.password = password
        handler.requestedLifetime = sessionLifetime

        handler.handlerActivated = onHandlerActivated
        handler.dataChanged = onDataChanged
        handler.errorCaught = { error in
            if let onErrorCaught = self.onErrorCaught {
                onErrorCaught(error)
            }
            
            switch error {
            case OPCUAError.code(let code, _):
                switch code {
                case .UA_STATUSCODE_BADTOOMANYPUBLISHREQUESTS:
                    //let interval = self.milliseconds + 100
                    //let info = OPCUAError.generic("ZenOPCUA: changed publishing interval from \(self.milliseconds) to \(interval) milliseconds")
                    self.onErrorCaught?(error)
                    self.startPublishing(milliseconds: self.milliseconds).whenComplete { _ in }
                case .UA_STATUSCODE_BADTIMEOUT, .UA_STATUSCODE_BADNOSUBSCRIPTION:
                    self.stopPublishing().whenComplete { _ in }
                default:
                    break
                }
            default:
                break
            }
        }
        handler.handlerRemoved = {
            if let onHandlerRemoved = self.onHandlerRemoved {
                onHandlerRemoved()
            }
            
            if ZenOPCUA.reconnect && !OPCUAHandler.isAcknowledge || OPCUAHandler.isAcknowledgeSecure {
                self.stop().whenComplete { _ in
                    if !OPCUAHandler.isAcknowledgeSecure && !OPCUAHandler.isAcknowledge { sleep(3) }
                    self.start().whenComplete { _ in }
                }
            }
        }
        
        return start()
            .flatMap { () -> EventLoopFuture<Void> in
                if self.handler.promises.index(forKey: 0) == nil {
                    self.handler.promises[0] = self.channel!.eventLoop.makePromise()
                }
                return self.handler.promises[0]!.futureResult.map { item -> Void in
                    ()
                }
            }
            .flatMapError { error -> EventLoopFuture<Void> in
                OPCUAHandler.isAcknowledge = false
                return self.eventLoopGroup.next().makeFailedFuture(error)
            }
    }
    
    public func disconnect(deleteSubscriptions: Bool = true) -> EventLoopFuture<Void> {
        ZenOPCUA.reconnect = false

        if deleteSubscriptions {
            return stopPublishing().flatMap { () -> EventLoopFuture<Void> in
                sleep(1)
                return self.closeSession(deleteSubscriptions: deleteSubscriptions).flatMap { (_) -> EventLoopFuture<Void> in
                    return self.stop()
                }
            }
        }

        return closeSession(deleteSubscriptions: deleteSubscriptions).flatMap { (_) -> EventLoopFuture<Void> in
            return self.stop()
        }
    }

    private func closeSession(deleteSubscriptions: Bool) -> EventLoopFuture<Promisable> {
        let eventLoop = eventLoopGroup.next()
        
        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }
        
        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise()
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = CloseSessionRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            deleteSubscriptions: deleteSubscriptions
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { item -> Promisable in
            timeout.cancel()
            return item
        }
    }

    public func browse(nodes: [BrowseDescription] = [BrowseDescription()]) -> EventLoopFuture<[BrowseResult]> {
        let eventLoop = eventLoopGroup.next()

        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise(of: Promisable.self)
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }
        
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = BrowseRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            nodesToBrowse: nodes
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [BrowseResult] in
            timeout.cancel()
            return promise as! [BrowseResult]
        }
    }

    public func read(nodes: [ReadValue]) -> EventLoopFuture<[DataValue]> {
        let eventLoop = eventLoopGroup.next()

        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise(of: Promisable.self)
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = ReadRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            nodesToRead: nodes
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)

        writeSyncronized(frame)

        return handler.promises[requestId]!.futureResult.map { promise -> [DataValue] in
            timeout.cancel()
            return promise as! [DataValue]
        }
    }

    public func write(nodes: [WriteValue]) -> EventLoopFuture<[StatusCodes]> {
        let eventLoop = eventLoopGroup.next()

        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise(of: Promisable.self)
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = WriteRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            nodesToWrite: nodes
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [StatusCodes] in
            timeout.cancel()
            return promise as! [StatusCodes]
        }
    }

    public func createSubscription(subscription: Subscription, startPublishing: Bool = true) -> EventLoopFuture<UInt32> {
        let eventLoop = eventLoopGroup.next()

        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise(of: Promisable.self)
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = CreateSubscriptionRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            subscription: subscription
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> UInt32 in
            timeout.cancel()
            let sub = promise as! CreateSubscriptionResponse
            if startPublishing {
                self.startPublishing(milliseconds: Int64(sub.revisedPubliscingInterval)).whenComplete { _ in }
            }
            return sub.subscriptionId
        }
    }
    
    public func createMonitoredItems(subscriptionId: UInt32, itemsToCreate: [MonitoredItemCreateRequest]) -> EventLoopFuture<[MonitoredItemCreateResult]> {
        let eventLoop = eventLoopGroup.next()

        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise(of: Promisable.self)
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = CreateMonitoredItemsRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            subscriptionId: subscriptionId,
            itemsToCreate: itemsToCreate
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [MonitoredItemCreateResult] in
            timeout.cancel()
            return promise as! [MonitoredItemCreateResult]
        }
    }
    
    public func deleteSubscriptions(subscriptionIds: [UInt32], stopPubliscing: Bool = true) -> EventLoopFuture<[StatusCodes]> {
        let eventLoop = eventLoopGroup.next()

        guard let authenticationToken = handler.authenticationToken else {
            return eventLoop.makeFailedFuture(OPCUAError.sessionError)
        }

        if stopPubliscing { stopPublishing().whenComplete { _ in } }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoop.makePromise(of: Promisable.self)
        let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
            self.handler.promises[requestId]?.fail(OPCUAError.timeout)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = DeleteSubscriptionsRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            subscriptionIds: subscriptionIds
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [StatusCodes] in
            timeout.cancel()
            return promise as! [StatusCodes]
        }
    }
    
    public func publish(subscriptionIds: [UInt32] = []) -> EventLoopFuture<Void> {
        guard let authenticationToken = handler.authenticationToken else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = self.handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)
        
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = PublishRequest(
            secureChannelId: handler.secureChannelId,
            tokenId: handler.tokenId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: authenticationToken,
            subscriptionAcknowledgements: subscriptionIds
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)

        writeSyncronized(frame)

        return handler.promises[requestId]!.futureResult.map { _ -> () in
            ()
        }
    }
    
    private func writeSyncronized(_ frame: OPCUAFrame, promise: EventLoopPromise<Void>? = nil) {
        dispatchQueue.async(flags: .barrier) {
            do {
                guard let channel = self.channel else { throw OPCUAError.connectionError}
                try channel.writeAndFlush(frame).wait()
                promise?.succeed(())
            } catch {
                promise?.fail(error)
            }
        }
    }
    
    private var publisher: RepeatedTask? = nil
    private var milliseconds: Int64 = 0
    
    public func startPublishing() {
        self.startPublishing(milliseconds: milliseconds).whenComplete { _ in }
    }

    public func startPublishing(milliseconds: Int64) -> EventLoopFuture<Void> {
        self.milliseconds = milliseconds
        
        return stopPublishing().map { () -> () in
            guard let channel = self.channel else { return }

            let time = TimeAmount.milliseconds(milliseconds)
            self.publisher = channel.eventLoop.scheduleRepeatedAsyncTask(initialDelay: time * 3, delay: time, { task -> EventLoopFuture<Void> in
                if self.handler.authenticationToken == nil {
                    return self.stopPublishing()
                }
                return self.publish()
            })
        }
    }

    public func stopPublishing() -> EventLoopFuture<Void> {
        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        if let pub = publisher {
            pub.cancel(promise: promise)
            publisher = nil
        } else {
            promise.succeed(())
        }
        return promise.futureResult
    }
}
