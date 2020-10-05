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
        OPCUAHandler.messageSecurityMode = messageSecurityMode
        let security = SecurityPolicy(securityPolicyUri: securityPolicy.uri)
        security.loadClientCertificate(certificate: certificate, privateKey: privateKey)
        OPCUAHandler.securityPolicy = security
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
            .channelOption(ChannelOptions.connectTimeout, value: TimeAmount.seconds(5))
            .channelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .channelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
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

        handler.sessionActive = nil
        handler.resetMessageID()

        if !OPCUAHandler.isAcknowledgeSecure {
            OPCUAHandler.endpoint = EndpointDescription()
        }
        
        channel.flush()
        return channel.close(mode: .all).map { () -> () in
            self.channel = nil
        }
    }
    
    public func connect(username: String? = nil, password: String? = nil, reconnect: Bool = true, sessionLifetime: UInt32 = 36000) -> EventLoopFuture<Void> {
        ZenOPCUA.reconnect = reconnect
        OPCUAHandler.isAcknowledge = true
        OPCUAHandler.isAcknowledgeSecure = OPCUAHandler.messageSecurityMode != .none
        
        handler.username = username
        handler.password = password
        handler.requestedLifetime = sessionLifetime * 1000

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
                    let interval = self.milliseconds + 100
                    let info = OPCUAError.generic("ZenOPCUA: changed publishing interval from \(self.milliseconds) to \(interval) milliseconds")
                    self.onErrorCaught?(info)
                    self.startPublishing(milliseconds: interval).whenComplete { _ in }
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
                OPCUAHandler.isAcknowledgeSecure = false
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
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }
        
        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise()

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
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult
    }

    public func browse(nodes: [BrowseDescription] = [BrowseDescription()]) -> EventLoopFuture<[BrowseResult]> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)

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
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [BrowseResult] in
            promise as! [BrowseResult]
        }
    }

    public func read(nodes: [ReadValue]) -> EventLoopFuture<[DataValue]> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)

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

        writeSyncronized(frame)

        return handler.promises[requestId]!.futureResult.map { promise -> [DataValue] in
            promise as! [DataValue]
        }
    }

    public func write(nodes: [WriteValue]) -> EventLoopFuture<[StatusCodes]> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)

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
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [StatusCodes] in
            return promise as! [StatusCodes]
        }
    }

    public func createSubscription(subscription: Subscription, startPublishing: Bool = true) -> EventLoopFuture<UInt32> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)

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
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> UInt32 in
            let sub = promise as! CreateSubscriptionResponse
            if startPublishing {
                self.startPublishing(milliseconds: Int64(sub.revisedPubliscingInterval)).whenComplete { _ in }
            }
            return sub.subscriptionId
        }
    }
    
    public func createMonitoredItems(subscriptionId: UInt32, itemsToCreate: [MonitoredItemCreateRequest]) -> EventLoopFuture<[MonitoredItemCreateResult]> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)

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
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [MonitoredItemCreateResult] in
            promise as! [MonitoredItemCreateResult]
        }
    }
    
    public func deleteSubscriptions(subscriptionIds: [UInt32], stopPubliscing: Bool = true) -> EventLoopFuture<[StatusCodes]> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        if stopPubliscing { stopPublishing().whenComplete { _ in } }

        let requestId = handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)

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
        
        writeSyncronized(frame)
        
        return handler.promises[requestId]!.futureResult.map { promise -> [StatusCodes] in
            promise as! [StatusCodes]
        }
    }
    
    public func publish(subscriptionIds: [UInt32] = []) -> EventLoopFuture<Void> {
        guard let session = handler.sessionActive else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.sessionError)
        }

        let requestId = self.handler.nextMessageID()
        handler.promises[requestId] = eventLoopGroup.next().makePromise(of: Promisable.self)
        
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = PublishRequest(
            secureChannelId: session.secureChannelId,
            tokenId: session.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: requestId,
            authenticationToken: session.authenticationToken,
            subscriptionAcknowledgements: subscriptionIds
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)

        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        writeSyncronized(frame, promise: promise)

        return promise.futureResult
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
    #if DEBUG
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    #endif
    
    public func startPublishing() {
        self.startPublishing(milliseconds: milliseconds).whenComplete { _ in }
    }

    public func startPublishing(milliseconds: Int64) -> EventLoopFuture<Void> {
        self.milliseconds = milliseconds
        
        return stopPublishing().map { () -> () in
            guard let channel = self.channel else { return }

            let time = TimeAmount.milliseconds(milliseconds)
            self.publisher = channel.eventLoop.scheduleRepeatedAsyncTask(initialDelay: time * 3, delay: time, { task -> EventLoopFuture<Void> in
                if self.handler.sessionActive != nil {
                    #if DEBUG
                    print("🔄 ZenOPCUA: publishing \(self.dateFormatter.string(from: Date()))")
                    #endif
                    return self.publish()
                }
                
                return self.stopPublishing()
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
