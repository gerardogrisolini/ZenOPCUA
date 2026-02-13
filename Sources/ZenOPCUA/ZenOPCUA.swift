//
//  ZenOPCUA.swift
//
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
@preconcurrency import NIOCore
import NIO

/// Errors that can occur during OPC UA operations.
public enum OPCUAError : Error {
    /// Connection to the OPC UA server failed or was lost.
    case connectionError
    
    /// Session-related error (e.g., no active session).
    case sessionError
    
    /// Operation timed out waiting for server response.
    case timeout
    
    /// Server returned a specific status code with optional reason.
    case code(_ status: StatusCodes, reason: String = "")
    
    /// Generic error with a descriptive message.
    case generic(_ text: String)
}

/// OPC UA client implementation using SwiftNIO for asynchronous networking.
///
/// `ZenOPCUA` provides a full-featured OPC UA client with support for:
/// - Secure and anonymous authentication
/// - Reading and writing node values
/// - Browsing the server address space
/// - Creating subscriptions and monitored items
/// - Automatic reconnection on connection loss
/// - SSL/TLS encryption with certificates
///
/// ## Usage Example
/// ```swift
/// let client = ZenOPCUA(
///     eventLoopGroup: group,
///     endpointUrl: "opc.tcp://localhost:4840"
/// )
///
/// // Connect to server
/// try await client.connect(username: "user", password: "pass").get()
///
/// // Read a node value
/// let node = ReadValue(nodeId: NodeIdNumeric(nameSpace: 2, identifier: 1001))
/// let values = try await client.read(nodes: [node]).get()
///
/// // Disconnect
/// try await client.disconnect().get()
/// ```
// Concurrency: public API may be called from any thread, but internal state is confined to the channel's EventLoop.
public final class ZenOPCUA: @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let state: OPCUAConnectionState
    private let handler: OPCUAHandler
    private var channel: Channel? = nil
    private var asyncChannel: NIOAsyncChannel<OPCUAFrame, OPCUAFrame>? = nil
    private var asyncChannelTask: Task<Void, Never>? = nil
    private var outboundContinuation: AsyncStream<OPCUAFrame>.Continuation? = nil
    
    /// Callback invoked when monitored items send data change notifications.
    /// Receives an array of `DataChange` objects containing the updated values.
    public var onDataChanged: OPCUADataChanged? = nil
    
    /// Callback invoked when the channel handler is activated and the connection is established.
    public var onHandlerActivated: OPCUAHandlerChange? = nil
    
    /// Callback invoked when the channel handler is removed, typically during disconnection or reconnection.
    public var onHandlerRemoved: OPCUAHandlerChange? = nil
    
    /// Callback invoked when an error occurs during communication with the OPC UA server.
    /// Receives an `Error` object describing the error condition.
    public var onErrorCaught: OPCUAErrorCaught? = nil
    
    /// Initializes a new OPC UA client instance.
    ///
    /// - Parameters:
    ///   - eventLoopGroup: The NIO EventLoopGroup for handling asynchronous operations
    ///   - endpointUrl: The OPC UA server endpoint URL (e.g., "opc.tcp://localhost:4840")
    ///   - applicationName: The client application name (default: "ZenOPCUA")
    ///   - messageSecurityMode: Security mode for messages (default: .none)
    ///   - securityPolicy: Security policy to use (default: .none)
    ///   - certificate: Optional PEM-encoded certificate for secure connections
    ///   - privateKey: Optional PEM-encoded private key for secure connections
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
        let state = OPCUAConnectionState()
        state.messageSecurityMode = messageSecurityMode
        state.securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicy.uri)
        state.securityPolicy.connectionState = state
        // Interop policy:
        // - SignAndEncrypt: always include thumbprint in OPN.
        // - Sign: include thumbprint when using certificate-based secure channel.
        state.includeServerThumbprintInOpn = (messageSecurityMode == .signAndEncrypt)

        // Load certificate immediately after creating security policy if using security
        if messageSecurityMode != .none {
            state.securityPolicy.loadLocalCertificate(certificate: certificate, privateKey: privateKey)
        }

        if messageSecurityMode == .sign && !state.securityPolicy.localCertificate.isEmpty {
            state.includeServerThumbprintInOpn = true
        }

        self.state = state
        self.handler = OPCUAHandler(state: state)
        handler.endpointUrl = endpointUrl
        handler.applicationName = applicationName
        handler.certificate = certificate
        handler.privateKey = privateKey
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
    
    @preconcurrency
    private func start() -> EventLoopFuture<Void> {
        let server = getHostFromEndpoint()

        return ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_KEEPALIVE), value: 1)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .channelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .channelOption(ChannelOptions.connectTimeout, value: .seconds(5))
            .channelInitializer { channel in
                self.initializeChannel(channel)
            }
            .connect(host: server.host, port: server.port)
            .flatMapThrowing { channel -> Void in
                self.channel = channel
                let asyncChannel = try NIOAsyncChannel(
                    wrappingChannelSynchronously: channel,
                    configuration: .init(
                        inboundType: OPCUAFrame.self,
                        outboundType: OPCUAFrame.self
                    )
                )
                self.asyncChannel = asyncChannel
                self.startAsyncChannelLoop(asyncChannel)
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

        let eventLoop = channel.eventLoop
        eventLoop.execute { [weak self] in
            guard let self = self else { return }
            self.outboundContinuation?.finish()
            self.outboundContinuation = nil
            self.asyncChannelTask?.cancel()
            self.asyncChannelTask = nil
            self.asyncChannel = nil
        }

        channel.flush()
        return channel.close(mode: .all).map { () -> () in
            self.channel = nil
        }
    }

    @preconcurrency
    private func initializeChannel(_ channel: Channel) -> EventLoopFuture<Void> {
        channel.pipeline.addHandler(OPCUAFrameCodecHandler(state: self.state))
    }

    private func startAsyncChannelLoop(_ asyncChannel: NIOAsyncChannel<OPCUAFrame, OPCUAFrame>) {
        let outboundStream = AsyncStream<OPCUAFrame> { continuation in
            self.outboundContinuation = continuation
        }
        let eventLoop = asyncChannel.channel.eventLoop

        asyncChannelTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await asyncChannel.executeThenClose { inbound, outbound in
                    let sendFrame: OPCUAHandler.FrameSender = { frame in
                        eventLoop.execute { [weak self] in
                            self?.outboundContinuation?.yield(frame)
                        }
                    }

                    eventLoop.execute { [weak self] in
                        self?.handler.activate(on: eventLoop, sendFrame: sendFrame)
                    }

                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for try await frame in inbound {
                                eventLoop.execute { [weak self] in
                                    self?.handler.handleInbound(frame: frame)
                                }
                            }
                        }
                        group.addTask {
                            for await frame in outboundStream {
                                try await outbound.write(frame)
                            }
                            outbound.finish()
                        }
                        _ = try await group.next()
                        group.cancelAll()
                    }
                }
            } catch {
                eventLoop.execute { [weak self] in
                    self?.handler.handleError(error: error)
                }
            }
            eventLoop.execute { [weak self] in
                self?.handler.notifyHandlerRemoved()
            }
        }
    }
    
    /// Connects to the OPC UA server and establishes a session.
    ///
    /// - Parameters:
    ///   - username: Optional username for authentication
    ///   - password: Optional password for authentication
    ///   - reconnect: Whether to automatically reconnect on connection loss (default: true)
    ///   - sessionLifetime: Session lifetime in milliseconds (default: 3600000 = 1 hour)
    /// - Returns: An EventLoopFuture that succeeds when the connection is established
    public func connect(username: String? = nil, password: String? = nil, reconnect: Bool = true, sessionLifetime: UInt32 = 3600000) -> EventLoopFuture<Void> {
        state.reconnect = reconnect
        state.isAcknowledge = true
        
        handler.username = username
        handler.password = password
        handler.requestedLifetime = sessionLifetime

        handler.handlerActivated = onHandlerActivated
        handler.dataChanged = onDataChanged
        handler.errorCaught = { [weak self] error in
            guard let self = self else { return }
            
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
        handler.handlerRemoved = { [weak self] in
            guard let self = self else { return }
            
            if let onHandlerRemoved = self.onHandlerRemoved {
                onHandlerRemoved()
            }
            
            if (state.reconnect && !state.isAcknowledge) || state.isUpgradingToSecure {
                self.stop().whenComplete { [weak self, state] _ in
                    guard let self = self else { return }
                    let delay: TimeAmount = (!state.isUpgradingToSecure && !state.isAcknowledge) ? .seconds(3) : .zero
                    self.scheduleDelay(delay).whenComplete { _ in
                        state.isUpgradingToSecure = false  // Reset flag after reconnection
                        self.start().whenComplete { _ in }
                    }
                }
            }
        }
        
        return start()
            .flatMap { () -> EventLoopFuture<Void> in
                let connectPromise = self.channel!.eventLoop.makePromise(of: Promisable.self)
                self.handler.promises[0] = connectPromise

                let timeoutTask = self.channel!.eventLoop.scheduleTask(in: .seconds(20)) { [weak self] in
                    guard let self = self else { return }
                    self.handler.failConnectIfPending(OPCUAError.timeout)
                }

                connectPromise.futureResult.whenComplete { _ in
                    timeoutTask.cancel()
                }

                return connectPromise.futureResult.map { item -> Void in
                    ()
                }
            }
            .flatMapError { [state] error -> EventLoopFuture<Void> in
                state.isAcknowledge = false
                return self.eventLoopGroup.next().makeFailedFuture(error)
            }
    }
    
    /// Disconnects from the OPC UA server and closes the session.
    ///
    /// - Parameter deleteSubscriptions: Whether to delete active subscriptions before disconnecting (default: true)
    /// - Returns: An EventLoopFuture that succeeds when disconnection is complete
    public func disconnect(deleteSubscriptions: Bool = true) -> EventLoopFuture<Void> {
        state.reconnect = false

        if deleteSubscriptions {
            return stopPublishing()
                .flatMap { self.scheduleDelay(.seconds(1)) }
                .flatMap { self.closeSession(deleteSubscriptions: deleteSubscriptions) }
                .flatMap { _ -> EventLoopFuture<Void> in
                    self.stop()
                }
        }

        return closeSession(deleteSubscriptions: deleteSubscriptions).flatMap { (_) -> EventLoopFuture<Void> in
            return self.stop()
        }
    }

    private func closeSession(deleteSubscriptions: Bool) -> EventLoopFuture<Promisable> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop
        
        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }
            
            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CloseSessionRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                deleteSubscriptions: deleteSubscriptions
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            
            self.writeSyncronized(frame, eventLoop: eventLoop)
            
            return promise.futureResult.map { item -> Promisable in
                timeout.cancel()
                return item
            }
        }
    }

    /// Browses the OPC UA server address space to discover nodes and their references.
    ///
    /// - Parameter nodes: Array of nodes to browse (default: root node)
    /// - Returns: An EventLoopFuture containing an array of browse results with node information and references
    public func browse(nodes: [BrowseDescription] = [BrowseDescription()]) -> EventLoopFuture<[BrowseResult]> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }
            
            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = BrowseRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                nodesToBrowse: nodes
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            
            self.writeSyncronized(frame, eventLoop: eventLoop)
            
            return promise.futureResult.flatMapThrowing { value -> [BrowseResult] in
                timeout.cancel()
                guard let results = value as? [BrowseResult] else {
                    throw OPCUAError.generic("Invalid BrowseResponse payload type")
                }
                return results
            }
        }
    }

    /// Reads values from one or more nodes on the OPC UA server.
    ///
    /// - Parameter nodes: Array of nodes to read with their attributes
    /// - Returns: An EventLoopFuture containing an array of data values read from the server
    public func read(nodes: [ReadValue]) -> EventLoopFuture<[DataValue]> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = ReadRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                nodesToRead: nodes
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)

            self.writeSyncronized(frame, eventLoop: eventLoop)

            return promise.futureResult.flatMapThrowing { value -> [DataValue] in
                timeout.cancel()
                guard let results = value as? [DataValue] else {
                    throw OPCUAError.generic("Invalid ReadResponse payload type")
                }
                return results
            }
        }
    }

    /// Writes values to one or more nodes on the OPC UA server.
    ///
    /// - Parameter nodes: Array of nodes to write with their new values
    /// - Returns: An EventLoopFuture containing an array of status codes indicating success or failure for each write operation
    public func write(nodes: [WriteValue]) -> EventLoopFuture<[StatusCodes]> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = WriteRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                nodesToWrite: nodes
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            
            self.writeSyncronized(frame, eventLoop: eventLoop)
            
            return promise.futureResult.flatMapThrowing { value -> [StatusCodes] in
                timeout.cancel()
                guard let results = value as? [StatusCodes] else {
                    throw OPCUAError.generic("Invalid WriteResponse payload type")
                }
                return results
            }
        }
    }

    /// Creates a subscription on the OPC UA server for monitoring data changes.
    ///
    /// - Parameters:
    ///   - subscription: Subscription configuration with publishing interval and other parameters
    ///   - startPublishing: Whether to automatically start publishing after creation (default: true)
    /// - Returns: An EventLoopFuture containing the subscription ID assigned by the server
    public func createSubscription(subscription: Subscription, startPublishing: Bool = true) -> EventLoopFuture<UInt32> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CreateSubscriptionRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                subscription: subscription
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            
            self.writeSyncronized(frame, eventLoop: eventLoop)
            
            return promise.futureResult.flatMapThrowing { value -> UInt32 in
                timeout.cancel()
                guard let sub = value as? CreateSubscriptionResponse else {
                    throw OPCUAError.generic("Invalid CreateSubscriptionResponse payload type")
                }
                if startPublishing {
                    self.startPublishing(milliseconds: Int64(sub.revisedPubliscingInterval)).whenComplete { _ in }
                }
                return sub.subscriptionId
            }
        }
    }
    
    /// Creates monitored items within a subscription to track specific node changes.
    ///
    /// - Parameters:
    ///   - subscriptionId: The ID of the subscription to add monitored items to
    ///   - itemsToCreate: Array of monitored item configurations specifying nodes to monitor
    /// - Returns: An EventLoopFuture containing an array of creation results with assigned item IDs and status
    public func createMonitoredItems(subscriptionId: UInt32, itemsToCreate: [MonitoredItemCreateRequest]) -> EventLoopFuture<[MonitoredItemCreateResult]> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CreateMonitoredItemsRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                subscriptionId: subscriptionId,
                itemsToCreate: itemsToCreate
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            
            self.writeSyncronized(frame, eventLoop: eventLoop)
            
            return promise.futureResult.flatMapThrowing { value -> [MonitoredItemCreateResult] in
                timeout.cancel()
                guard let results = value as? [MonitoredItemCreateResult] else {
                    throw OPCUAError.generic("Invalid CreateMonitoredItemsResponse payload type")
                }
                return results
            }
        }
    }
    
    /// Deletes one or more subscriptions from the OPC UA server.
    ///
    /// - Parameters:
    ///   - subscriptionIds: Array of subscription IDs to delete
    ///   - stopPubliscing: Whether to stop publishing before deletion (default: true)
    /// - Returns: An EventLoopFuture containing an array of status codes indicating success or failure for each deletion
    public func deleteSubscriptions(subscriptionIds: [UInt32], stopPubliscing: Bool = true) -> EventLoopFuture<[StatusCodes]> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        if stopPubliscing { stopPublishing().whenComplete { _ in } }

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                self.handler.promises[requestId]?.fail(OPCUAError.timeout)
            }

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = DeleteSubscriptionsRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                subscriptionIds: subscriptionIds
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            
            self.writeSyncronized(frame, eventLoop: eventLoop)
            
            return promise.futureResult.flatMapThrowing { value -> [StatusCodes] in
                timeout.cancel()
                guard let results = value as? [StatusCodes] else {
                    throw OPCUAError.generic("Invalid DeleteSubscriptionsResponse payload type")
                }
                return results
            }
        }
    }
    
    /// Publishes a request to receive data change notifications from subscriptions.
    ///
    /// - Parameter subscriptionIds: Array of subscription IDs to acknowledge (default: empty for all subscriptions)
    /// - Returns: An EventLoopFuture that succeeds when the publish request completes
    public func publish(subscriptionIds: [UInt32] = []) -> EventLoopFuture<Void> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = channel.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationToken = self.handler.authenticationToken else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            self.handler.promises[requestId] = promise
            
            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = PublishRequest(
                secureChannelId: self.handler.secureChannelId,
                tokenId: self.handler.tokenId,
                requestId: requestId,
                requestHandle: requestId,
                authenticationToken: authenticationToken,
                subscriptionAcknowledgements: subscriptionIds
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)

            self.writeSyncronized(frame, eventLoop: eventLoop)

            return promise.futureResult.map { _ -> () in
                ()
            }
        }
    }
    
    private func writeSyncronized(_ frame: OPCUAFrame, eventLoop: EventLoop, promise: EventLoopPromise<Void>? = nil) {
        eventLoop.execute { [weak self] in
            guard let self = self, let continuation = self.outboundContinuation else {
                promise?.fail(OPCUAError.connectionError)
                return
            }
            continuation.yield(frame)
            promise?.succeed(())
        }
    }
    
    private var publisher: RepeatedTask? = nil
    private var milliseconds: Int64 = 0
    
    /// Starts the automatic publishing mechanism using the previously configured interval.
    ///
    /// This method resumes publishing with the last interval set by `startPublishing(milliseconds:)`.
    public func startPublishing() {
        self.startPublishing(milliseconds: milliseconds).whenComplete { _ in }
    }

    /// Starts automatic publishing to receive periodic data change notifications from subscriptions.
    ///
    /// This creates a repeating task that sends publish requests at the specified interval.
    /// The task continues until `stopPublishing()` is called or the connection is closed.
    ///
    /// - Parameter milliseconds: Publishing interval in milliseconds
    /// - Returns: An EventLoopFuture that succeeds when the publishing mechanism is started
    public func startPublishing(milliseconds: Int64) -> EventLoopFuture<Void> {
        self.milliseconds = milliseconds
        
        return stopPublishing().map { [weak self] () -> () in
            guard let self = self else { return }
            guard let channel = self.channel else { return }

            let time = TimeAmount.milliseconds(milliseconds)
            self.publisher = channel.eventLoop.scheduleRepeatedAsyncTask(initialDelay: time * 3, delay: time, { [weak self] task -> EventLoopFuture<Void> in
                guard let self = self else {
                    return channel.eventLoop.makeSucceededVoidFuture()
                }
                if self.handler.authenticationToken == nil {
                    return self.stopPublishing()
                }
                return self.publish()
            })
        }
    }

    /// Stops the automatic publishing mechanism.
    ///
    /// Cancels the repeating publish task that was started by `startPublishing(milliseconds:)`.
    ///
    /// - Returns: An EventLoopFuture that succeeds when the publishing mechanism is stopped
    public func stopPublishing() -> EventLoopFuture<Void> {
        guard let channel = channel else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        let eventLoop = channel.eventLoop
        return eventLoop.flatSubmit {
            let promise = eventLoop.makePromise(of: Void.self)
            if let pub = self.publisher {
                pub.cancel(promise: promise)
                self.publisher = nil
            } else {
                promise.succeed(())
            }
            return promise.futureResult
        }
    }

    private func scheduleDelay(_ delay: TimeAmount) -> EventLoopFuture<Void> {
        let eventLoop = eventLoopGroup.next()
        if delay == .zero {
            return eventLoop.makeSucceededVoidFuture()
        }
        let promise = eventLoop.makePromise(of: Void.self)
        eventLoop.scheduleTask(in: delay) {
            promise.succeed(())
        }
        return promise.futureResult
    }
}


// MARK: - Async/Await API

extension ZenOPCUA {
    
    /// Connects to the OPC UA server using async/await.
    /// - Parameters:
    ///   - username: Optional username for authentication
    ///   - password: Optional password for authentication
    ///   - reconnect: Whether to automatically reconnect on connection loss
    ///   - sessionLifetime: Session lifetime in milliseconds
    /// - Throws: OPCUAError if connection fails
    public func connect(
        username: String? = nil,
        password: String? = nil,
        reconnect: Bool = true,
        sessionLifetime: UInt32 = 3600000
    ) async throws {
        try await connect(
            username: username,
            password: password,
            reconnect: reconnect,
            sessionLifetime: sessionLifetime
        ).get()
    }
    
    /// Disconnects from the OPC UA server using async/await.
    /// - Parameter deleteSubscriptions: Whether to delete subscriptions before disconnecting
    /// - Throws: OPCUAError if disconnection fails
    public func disconnect(deleteSubscriptions: Bool = true) async throws {
        try await disconnect(deleteSubscriptions: deleteSubscriptions).get()
    }
    
    /// Browses nodes on the OPC UA server using async/await.
    /// - Parameter nodes: Array of nodes to browse (defaults to root node)
    /// - Returns: Array of browse results
    /// - Throws: OPCUAError if browse operation fails
    public func browse(nodes: [BrowseDescription] = [BrowseDescription()]) async throws -> [BrowseResult] {
        try await browse(nodes: nodes).get()
    }
    
    /// Reads values from nodes on the OPC UA server using async/await.
    /// - Parameter nodes: Array of nodes to read
    /// - Returns: Array of data values
    /// - Throws: OPCUAError if read operation fails
    public func read(nodes: [ReadValue]) async throws -> [DataValue] {
        try await read(nodes: nodes).get()
    }
    
    /// Writes values to nodes on the OPC UA server using async/await.
    /// - Parameter nodes: Array of write values
    /// - Returns: Array of status codes indicating success/failure for each write
    /// - Throws: OPCUAError if write operation fails
    public func write(nodes: [WriteValue]) async throws -> [StatusCodes] {
        try await write(nodes: nodes).get()
    }
    
    /// Creates a subscription on the OPC UA server using async/await.
    /// - Parameters:
    ///   - subscription: Subscription configuration
    ///   - startPublishing: Whether to automatically start publishing
    /// - Returns: Subscription ID
    /// - Throws: OPCUAError if subscription creation fails
    public func createSubscription(
        subscription: Subscription,
        startPublishing: Bool = true
    ) async throws -> UInt32 {
        try await createSubscription(subscription: subscription, startPublishing: startPublishing).get()
    }
    
    /// Creates monitored items for a subscription using async/await.
    /// - Parameters:
    ///   - subscriptionId: ID of the subscription
    ///   - itemsToCreate: Array of items to monitor
    /// - Returns: Array of monitored item creation results
    /// - Throws: OPCUAError if monitored item creation fails
    public func createMonitoredItems(
        subscriptionId: UInt32,
        itemsToCreate: [MonitoredItemCreateRequest]
    ) async throws -> [MonitoredItemCreateResult] {
        try await createMonitoredItems(subscriptionId: subscriptionId, itemsToCreate: itemsToCreate).get()
    }
    
    /// Deletes subscriptions from the OPC UA server using async/await.
    /// - Parameters:
    ///   - subscriptionIds: Array of subscription IDs to delete
    ///   - stopPubliscing: Whether to stop publishing before deletion
    /// - Returns: Array of status codes indicating success/failure for each deletion
    /// - Throws: OPCUAError if deletion fails
    public func deleteSubscriptions(
        subscriptionIds: [UInt32],
        stopPubliscing: Bool = true
    ) async throws -> [StatusCodes] {
        try await deleteSubscriptions(subscriptionIds: subscriptionIds, stopPubliscing: stopPubliscing).get()
    }
    
    /// Publishes to subscriptions using async/await.
    /// - Parameter subscriptionIds: Array of subscription IDs
    /// - Throws: OPCUAError if publish operation fails
    public func publish(subscriptionIds: [UInt32] = []) async throws {
        try await publish(subscriptionIds: subscriptionIds).get()
    }
    
    /// Starts publishing with async/await support.
    /// - Parameter milliseconds: Publishing interval in milliseconds
    /// - Throws: OPCUAError if starting publishing fails
    public func startPublishing(milliseconds: Int64) async throws {
        try await startPublishing(milliseconds: milliseconds).get()
    }
    
    /// Stops publishing with async/await support.
    /// - Throws: OPCUAError if stopping publishing fails
    public func stopPublishing() async throws {
        try await stopPublishing().get()
    }
    
    /// Creates an async stream of data changes from subscriptions.
    /// This allows consuming data changes using async/await patterns.
    /// - Returns: AsyncStream that yields arrays of data changes
    ///
    /// Example usage:
    /// ```swift
    /// for await changes in client.dataChanges() {
    ///     for change in changes {
    ///         print("Node: \(change.clientHandle), Value: \(change.value)")
    ///     }
    /// }
    /// ```
    public func dataChanges() -> AsyncStream<[DataChange]> {
        AsyncStream { continuation in
            self.onDataChanged = { changes in
                continuation.yield(changes)
            }
            
            continuation.onTermination = { @Sendable _ in
                // Cleanup when stream is cancelled
            }
        }
    }
    
    /// Creates an async stream of errors.
    /// This allows consuming errors using async/await patterns.
    /// - Returns: AsyncStream that yields errors
    ///
    /// Example usage:
    /// ```swift
    /// for await error in client.errors() {
    ///     print("Error: \(error)")
    /// }
    /// ```
    public func errors() -> AsyncStream<Error> {
        AsyncStream { continuation in
            self.onErrorCaught = { error in
                continuation.yield(error)
            }
            
            continuation.onTermination = { @Sendable _ in
                // Cleanup when stream is cancelled
            }
        }
    }
}
