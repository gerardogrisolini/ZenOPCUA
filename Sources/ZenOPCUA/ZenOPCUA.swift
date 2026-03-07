//
//  ZenOPCUA.swift
//
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
@preconcurrency import NIOCore
import NIO
import NIOConcurrencyHelpers

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
    /// let node = ReadValue(nodeValue: .numeric(nameSpace: 2, identifier: 1001))
/// let values = try await client.read(nodes: [node]).get()
///
/// // Disconnect
/// try await client.disconnect().get()
/// ```
// Concurrency: public API may be called from any thread, but internal state is confined to the channel's EventLoop.
public final class ZenOPCUA: Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let state: OPCUAConnectionState
    private let handler: OPCUAHandler
    private let publishingRuntime = PublishingRuntime()
    private let asyncChannelRuntime = AsyncChannelRuntime()
    private let coordinatorSnapshotProvider: ConnectionCoordinatorSnapshotProvider
    private let connectionCoordinator: ConnectionCoordinator
    private let asyncObservers = AsyncObserverStore()
    private let callbackRuntime = ClientCallbackRuntime()

    private var coordinatorSnapshot: ConnectionCoordinatorSnapshot {
        coordinatorSnapshotProvider.currentSnapshot
    }

    private var currentTransport: (channel: Channel, eventLoop: EventLoop)? {
        let connectionSnapshot = coordinatorSnapshot
        guard let channel = connectionSnapshot.currentChannel else {
            return nil
        }
        return (channel: channel, eventLoop: channel.eventLoop)
    }

    private func performCoordinatorMutation(
        on eventLoop: EventLoop? = nil,
        _ operation: @escaping @Sendable (ConnectionCoordinator) async -> Void
    ) -> EventLoopFuture<Void> {
        let callbackLoop = eventLoop ?? eventLoopGroup.next()
        let completion = callbackLoop.makePromise(of: Void.self)

        Task {
            await operation(connectionCoordinator)
            callbackLoop.execute {
                completion.succeed(())
            }
        }

        return completion.futureResult
    }

    
    /// Callback invoked when monitored items send data change notifications.
    /// Receives an array of `DataChange` objects containing the updated values.
    public var onDataChanged: OPCUADataChanged? {
        get { callbackRuntime.currentOnDataChanged }
        set { callbackRuntime.updateOnDataChanged(newValue) }
    }
    
    /// Callback invoked when the channel handler is activated and the connection is established.
    public var onHandlerActivated: OPCUAHandlerChange? {
        get { callbackRuntime.currentOnHandlerActivated }
        set { callbackRuntime.updateOnHandlerActivated(newValue) }
    }
    
    /// Callback invoked when the channel handler is removed, typically during disconnection or reconnection.
    public var onHandlerRemoved: OPCUAHandlerChange? {
        get { callbackRuntime.currentOnHandlerRemoved }
        set { callbackRuntime.updateOnHandlerRemoved(newValue) }
    }
    
    /// Callback invoked when an error occurs during communication with the OPC UA server.
    /// Receives an `Error` object describing the error condition.
    public var onErrorCaught: OPCUAErrorCaught? {
        get { callbackRuntime.currentOnErrorCaught }
        set { callbackRuntime.updateOnErrorCaught(newValue) }
    }
    
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
        state.replaceSecurityPolicy(uri: securityPolicy.uri)
        // Interop policy:
        // - SignAndEncrypt: always include thumbprint in OPN.
        // - Sign: include thumbprint when using certificate-based secure channel.
        state.includeServerThumbprintInOpn = (messageSecurityMode == .signAndEncrypt)

        // Load certificate immediately after creating security policy if using security
        if messageSecurityMode != .none {
            state.loadLocalCertificate(certificate: certificate, privateKey: privateKey)
        }

        if messageSecurityMode == .sign && state.hasLocalCertificate {
            state.includeServerThumbprintInOpn = true
        }

        let initialSnapshot = ConnectionCoordinator.buildInitialSnapshot()
        let snapshotProvider = ConnectionCoordinatorSnapshotProvider(snapshot: initialSnapshot)
        let connectionCoordinator = ConnectionCoordinator(snapshotProvider: snapshotProvider)

        self.state = state
        self.coordinatorSnapshotProvider = snapshotProvider
        self.connectionCoordinator = connectionCoordinator
        self.handler = OPCUAHandler(
            state: state,
            connectionCoordinator: connectionCoordinator,
            snapshotProvider: snapshotProvider
        )
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
        let connectionSnapshot = coordinatorSnapshot
        guard connectionSnapshot.canStartTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.generic("Invalid connection transition"))
        }
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
            .flatMap { channel in
                self.performCoordinatorMutation(on: channel.eventLoop) { coordinator in
                    await coordinator.setChannel(channel)
                }
                .flatMapThrowing {
                    let asyncChannel = try NIOAsyncChannel(
                        wrappingChannelSynchronously: channel,
                        configuration: .init(
                            inboundType: OPCUAFrame.self,
                            outboundType: OPCUAFrame.self
                        )
                    )
                    self.startAsyncChannelLoop(asyncChannel)
                }
            }
            .flatMapError { error -> EventLoopFuture<Void> in
                self.performCoordinatorMutation { coordinator in
                    await coordinator.markStartFailed()
                }
                .flatMap {
                    self.eventLoopGroup.next().makeFailedFuture(error)
                }
            }
    }
    
    private func stop() -> EventLoopFuture<Void> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }

        handler.resetAll()

        let channel = transport.channel
        let eventLoop = transport.eventLoop
        let shutdownPromise = eventLoop.makePromise(of: Void.self)
        Task { [weak self] in
            guard let self else {
                eventLoop.execute {
                    shutdownPromise.succeed(())
                }
                return
            }

            await self.asyncChannelRuntime.shutdown()
            eventLoop.execute {
                shutdownPromise.succeed(())
            }
        }

        return shutdownPromise.futureResult.flatMap {
            channel.flush()
            return channel.close(mode: .all).flatMap {
                self.performCoordinatorMutation(on: eventLoop) { coordinator in
                    await coordinator.clearConnection()
                }
            }
        }
    }

    @preconcurrency
    private func initializeChannel(_ channel: Channel) -> EventLoopFuture<Void> {
        channel.pipeline.addHandler(
            OPCUAFrameCodecHandler(
                state: self.state,
                snapshotProvider: self.coordinatorSnapshotProvider
            )
        )
    }

    private func startAsyncChannelLoop(_ asyncChannel: NIOAsyncChannel<OPCUAFrame, OPCUAFrame>) {
        let eventLoop = asyncChannel.channel.eventLoop
        let runtime = self.asyncChannelRuntime

        let task = Task { [weak self] in
            guard let self = self else { return }
            let outboundStream = await runtime.prepareOutboundStream()
            do {
                try await asyncChannel.executeThenClose { inbound, outbound in
                    let sendFrame: OPCUAHandler.FrameSender = { frame in
                        Task {
                            _ = await runtime.write(frame)
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
            await runtime.clearFinishedLoop()
        }

        Task {
            await runtime.activate(task: task)
        }
    }

    func notifyDataChangeObservers(_ changes: [DataChange]) {
        Task {
            await asyncObservers.yieldDataChanges(changes)
        }
    }

    func notifyErrorObservers(_ error: Error) {
        Task {
            await asyncObservers.yieldError(error)
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
        let connectionSnapshot = coordinatorSnapshot
        guard connectionSnapshot.canBeginConnect else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.generic("Connection is already active or starting"))
        }
        handler.username = username
        handler.password = password
        handler.requestedLifetime = sessionLifetime

        handler.handlerActivated = callbackRuntime.currentOnHandlerActivated
        handler.dataChanged = { [weak self] changes in
            guard let self = self else { return }
            self.notifyDataChangeObservers(changes)
            self.callbackRuntime.currentOnDataChanged?(changes)
        }
        handler.errorCaught = { [weak self] error in
            guard let self = self else { return }

            self.notifyErrorObservers(error)
            self.callbackRuntime.currentOnErrorCaught?(error)
            
            switch error {
            case OPCUAError.code(let code, _):
                switch code {
                case .UA_STATUSCODE_BADTOOMANYPUBLISHREQUESTS:
                    //let interval = self.milliseconds + 100
                    //let info = OPCUAError.generic("ZenOPCUA: changed publishing interval from \(self.milliseconds) to \(interval) milliseconds")
                    self.callbackRuntime.currentOnErrorCaught?(error)
                    Task { [weak self] in
                        guard let self = self else { return }
                        let milliseconds = await self.publishingRuntime.currentMilliseconds()
                        self.startPublishing(milliseconds: milliseconds).whenComplete { _ in }
                    }
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
            
            if let onHandlerRemoved = self.callbackRuntime.currentOnHandlerRemoved {
                onHandlerRemoved()
            }

            let connectionSnapshot = self.coordinatorSnapshot
            if connectionSnapshot.shouldAttemptReconnect
                && ((connectionSnapshot.lifecycleReconnectEnabled && !connectionSnapshot.lifecycleIsAcknowledging)
                    || connectionSnapshot.lifecycleIsUpgradingToSecure) {
                Task { [weak self] in
                    guard let self = self else { return }
                    guard await self.connectionCoordinator.enterReconnectBackoff() else { return }
                    self.stop().whenComplete { [weak self] _ in
                        guard let self = self else { return }
                        let delay: TimeAmount = (!connectionSnapshot.lifecycleIsUpgradingToSecure
                            && !connectionSnapshot.lifecycleIsAcknowledging) ? .seconds(3) : .zero
                        self.scheduleDelay(delay).whenComplete { [weak self] _ in
                            guard let self = self else { return }
                            Task { [weak self] in
                                guard let self = self else { return }
                                await self.connectionCoordinator.setUpgradingToSecure(false)
                                guard await self.connectionCoordinator.resumeReconnectFromBackoff() else { return }
                                self.start().whenComplete { _ in }
                            }
                        }
                    }
                }
            }
        }
        
        return performCoordinatorMutation { coordinator in
            await coordinator.prepareForConnect()
            await coordinator.setReconnectEnabled(reconnect)
        }
            .flatMap { self.start() }
            .flatMap { () -> EventLoopFuture<Void> in
                let connectionSnapshot = self.coordinatorSnapshot
                guard let eventLoop = connectionSnapshot.currentEventLoop else {
                    return self.eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
                }
                let connectPromise = eventLoop.makePromise(of: Promisable.self)

                return self.handler.registerPromise(connectPromise, for: 0, on: eventLoop).flatMap {
                    let timeoutTask = eventLoop.scheduleTask(in: .seconds(20)) { [weak self] in
                        guard let self = self else { return }
                        self.handler.failConnectIfPending(OPCUAError.timeout)
                    }

                    connectPromise.futureResult.whenComplete { _ in
                        timeoutTask.cancel()
                    }

                    return connectPromise.futureResult.map { _ -> Void in
                        ()
                    }
                }
            }
            .flatMapError { error -> EventLoopFuture<Void> in
                self.performCoordinatorMutation { coordinator in
                    await coordinator.completeAcknowledge()
                }
                .flatMap {
                    self.eventLoopGroup.next().makeFailedFuture(error)
                }
            }
    }
    
    /// Disconnects from the OPC UA server and closes the session.
    ///
    /// - Parameter deleteSubscriptions: Whether to delete active subscriptions before disconnecting (default: true)
    /// - Returns: An EventLoopFuture that succeeds when disconnection is complete
    public func disconnect(deleteSubscriptions: Bool = true) -> EventLoopFuture<Void> {
        let connectionSnapshot = coordinatorSnapshot
        guard connectionSnapshot.canBeginDisconnect else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.generic("Connection is not active"))
        }
        let disconnectPreparation = performCoordinatorMutation { coordinator in
            await coordinator.prepareForDisconnect()
            await coordinator.disableReconnect()
        }

        if deleteSubscriptions {
            return disconnectPreparation.flatMap { self.stopPublishing() }
                .flatMap { self.scheduleDelay(.seconds(1)) }
                .flatMap { self.closeSession(deleteSubscriptions: deleteSubscriptions) }
                .flatMap { _ -> EventLoopFuture<Void> in
                    self.stop()
                }
        }

        return disconnectPreparation.flatMap {
            self.closeSession(deleteSubscriptions: deleteSubscriptions)
        }.flatMap { (_) -> EventLoopFuture<Void> in
            return self.stop()
        }
    }

    private func closeSession(deleteSubscriptions: Bool) -> EventLoopFuture<Promisable> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop
        
        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }
            
            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = CloseSessionRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }

    /// Browses the OPC UA server address space to discover nodes and their references.
    ///
    /// - Parameter nodes: Array of nodes to browse (default: root node)
    /// - Returns: An EventLoopFuture containing an array of browse results with node information and references
    public func browse(nodes: [BrowseDescription] = [BrowseDescription(nodeValue: .base(identifier: 0x55))]) -> EventLoopFuture<[BrowseResult]> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = BrowseRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }

    /// Browses nodes on the OPC UA server using value-based node identifiers.
    /// - Parameter nodeValues: Array of node values to browse
    /// - Returns: An EventLoopFuture containing an array of browse results
    public func browse(nodeValues: [NodeValue]) -> EventLoopFuture<[BrowseResult]> {
        browse(nodes: nodeValues.map { BrowseDescription(nodeValue: $0) })
    }

    /// Reads values from one or more nodes on the OPC UA server.
    ///
    /// - Parameter nodes: Array of nodes to read with their attributes
    /// - Returns: An EventLoopFuture containing an array of data values read from the server
    public func read(nodes: [ReadValue]) -> EventLoopFuture<[DataValue]> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = ReadRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }

    /// Reads values from nodes on the OPC UA server using value-based node identifiers.
    /// - Parameters:
    ///   - nodeValues: Array of node values to read
    ///   - attributeId: OPC UA attribute to read (defaults to Value)
    ///   - dataEncoding: Optional data encoding descriptor
    /// - Returns: An EventLoopFuture containing an array of data values
    public func read(
        nodeValues: [NodeValue],
        attributeId: UInt32 = 0x0000000d,
        dataEncoding: QualifiedName = QualifiedName()
    ) -> EventLoopFuture<[DataValue]> {
        read(nodes: nodeValues.map {
            ReadValue(nodeValue: $0, attributeId: attributeId, dataEncoding: dataEncoding)
        })
    }

    /// Writes values to one or more nodes on the OPC UA server.
    ///
    /// - Parameter nodes: Array of nodes to write with their new values
    /// - Returns: An EventLoopFuture containing an array of status codes indicating success or failure for each write operation
    public func write(nodes: [WriteValue]) -> EventLoopFuture<[StatusCodes]> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = WriteRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }

    /// Writes values to nodes on the OPC UA server using value-based node identifiers.
    /// - Parameters:
    ///   - nodeValues: Array of node values to write to
    ///   - values: Array of payloads matching `nodeValues` by index
    ///   - attributeId: OPC UA attribute to write (defaults to Value)
    /// - Returns: An EventLoopFuture containing an array of status codes
    public func write(
        nodeValues: [NodeValue],
        values: [DataValue],
        attributeId: UInt32 = 0x0000000d
    ) -> EventLoopFuture<[StatusCodes]> {
        guard nodeValues.count == values.count else {
            return eventLoopGroup.next().makeFailedFuture(
                OPCUAError.generic("NodeValue and DataValue counts must match")
            )
        }

        let writes = zip(nodeValues, values).map {
            WriteValue(nodeValue: $0.0, attributeId: attributeId, value: $0.1)
        }
        return write(nodes: writes)
    }

    /// Creates a subscription on the OPC UA server for monitoring data changes.
    ///
    /// - Parameters:
    ///   - subscription: Subscription configuration with publishing interval and other parameters
    ///   - startPublishing: Whether to automatically start publishing after creation (default: true)
    /// - Returns: An EventLoopFuture containing the subscription ID assigned by the server
    public func createSubscription(subscription: Subscription, startPublishing: Bool = true) -> EventLoopFuture<UInt32> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = CreateSubscriptionRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }
    
    /// Creates monitored items within a subscription to track specific node changes.
    ///
    /// - Parameters:
    ///   - subscriptionId: The ID of the subscription to add monitored items to
    ///   - itemsToCreate: Array of monitored item configurations specifying nodes to monitor
    /// - Returns: An EventLoopFuture containing an array of creation results with assigned item IDs and status
    public func createMonitoredItems(subscriptionId: UInt32, itemsToCreate: [MonitoredItemCreateRequest]) -> EventLoopFuture<[MonitoredItemCreateResult]> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = CreateMonitoredItemsRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }
    
    /// Deletes one or more subscriptions from the OPC UA server.
    ///
    /// - Parameters:
    ///   - subscriptionIds: Array of subscription IDs to delete
    ///   - stopPubliscing: Whether to stop publishing before deletion (default: true)
    /// - Returns: An EventLoopFuture containing an array of status codes indicating success or failure for each deletion
    public func deleteSubscriptions(subscriptionIds: [UInt32], stopPubliscing: Bool = true) -> EventLoopFuture<[StatusCodes]> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        if stopPubliscing { stopPublishing().whenComplete { _ in } }

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let timeout = eventLoop.scheduleTask(in: .seconds(2)) {
                    self.handler.failPromiseIfPending(requestId, error: OPCUAError.timeout)
                }

                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = DeleteSubscriptionsRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
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
    }
    
    /// Publishes a request to receive data change notifications from subscriptions.
    ///
    /// - Parameter subscriptionIds: Array of subscription IDs to acknowledge (default: empty for all subscriptions)
    /// - Returns: An EventLoopFuture that succeeds when the publish request completes
    public func publish(subscriptionIds: [UInt32] = []) -> EventLoopFuture<Void> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        let eventLoop = transport.eventLoop

        return eventLoop.flatSubmit {
            guard let authenticationTokenValue = self.handler.authenticationTokenValue else {
                return eventLoop.makeFailedFuture(OPCUAError.sessionError)
            }

            let requestId = self.handler.nextMessageID()
            let promise = eventLoop.makePromise(of: Promisable.self)
            return self.handler.registerPromise(promise, for: requestId, on: eventLoop).flatMap {
                let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
                let body = PublishRequest(
                    secureChannelId: self.handler.secureChannelId,
                    tokenId: self.handler.tokenId,
                    requestId: requestId,
                    requestHandle: requestId,
                    authenticationTokenValue: authenticationTokenValue,
                    subscriptionAcknowledgements: subscriptionIds
                )
                let frame = OPCUAFrame(head: head, body: body.bytes)

                self.writeSyncronized(frame, eventLoop: eventLoop)

                return promise.futureResult.map { _ -> () in
                    ()
                }
            }
        }
    }
    
    private func writeSyncronized(_ frame: OPCUAFrame, eventLoop: EventLoop, promise: EventLoopPromise<Void>? = nil) {
        eventLoop.execute { [weak self] in
            guard let self = self else {
                promise?.fail(OPCUAError.connectionError)
                return
            }

            Task { [weak self] in
                guard let self = self else {
                    eventLoop.execute {
                        promise?.fail(OPCUAError.connectionError)
                    }
                    return
                }

                let didWrite = await self.asyncChannelRuntime.write(frame)
                eventLoop.execute {
                    if didWrite {
                        promise?.succeed(())
                    } else {
                        promise?.fail(OPCUAError.connectionError)
                    }
                }
            }
        }
    }
    
    /// Starts the automatic publishing mechanism using the previously configured interval.
    ///
    /// This method resumes publishing with the last interval set by `startPublishing(milliseconds:)`.
    public func startPublishing() {
        Task { [weak self] in
            guard let self = self else { return }
            let milliseconds = await self.publishingRuntime.currentMilliseconds()
            self.startPublishing(milliseconds: milliseconds).whenComplete { _ in }
        }
    }

    /// Starts automatic publishing to receive periodic data change notifications from subscriptions.
    ///
    /// This creates a repeating task that sends publish requests at the specified interval.
    /// The task continues until `stopPublishing()` is called or the connection is closed.
    ///
    /// - Parameter milliseconds: Publishing interval in milliseconds
    /// - Returns: An EventLoopFuture that succeeds when the publishing mechanism is started
    public func startPublishing(milliseconds: Int64) -> EventLoopFuture<Void> {
        let connectionSnapshot = coordinatorSnapshot
        guard connectionSnapshot.currentPhase == .connected || connectionSnapshot.currentPhase == .reconnecting else {
            return eventLoopGroup.next().makeFailedFuture(OPCUAError.connectionError)
        }
        Task {
            await self.publishingRuntime.setMilliseconds(milliseconds)
        }
        
        return stopPublishing().map { [weak self] () -> () in
            guard let self = self else { return }
            guard let transport = self.currentTransport else { return }

            let time = TimeAmount.milliseconds(milliseconds)
            let publisher = transport.eventLoop.scheduleRepeatedAsyncTask(initialDelay: time * 3, delay: time, { [weak self] task -> EventLoopFuture<Void> in
                guard let self = self else {
                    return transport.eventLoop.makeSucceededVoidFuture()
                }
                if self.handler.authenticationTokenValue == nil {
                    return self.stopPublishing()
                }
                return self.publish()
            })
            Task {
                await self.publishingRuntime.storePublisher(publisher)
            }
        }
    }

    /// Stops the automatic publishing mechanism.
    ///
    /// Cancels the repeating publish task that was started by `startPublishing(milliseconds:)`.
    ///
    /// - Returns: An EventLoopFuture that succeeds when the publishing mechanism is stopped
    public func stopPublishing() -> EventLoopFuture<Void> {
        guard let transport = currentTransport else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        let eventLoop = transport.eventLoop
        return eventLoop.flatSubmit {
            let promise = eventLoop.makePromise(of: Void.self)
            Task { [weak self] in
                guard let self = self else {
                    eventLoop.execute {
                        promise.succeed(())
                    }
                    return
                }
                let publisher = await self.publishingRuntime.takePublisher()
                eventLoop.execute {
                    if let publisher = publisher {
                        publisher.cancel(promise: promise)
                    } else {
                        promise.succeed(())
                    }
                }
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
    public func browse(nodes: [BrowseDescription] = [BrowseDescription(nodeValue: .base(identifier: 0x55))]) async throws -> [BrowseResult] {
        try await browse(nodes: nodes).get()
    }

    /// Browses nodes on the OPC UA server using value-based node identifiers.
    /// - Parameter nodeValues: Array of node values to browse
    /// - Returns: Array of browse results
    /// - Throws: OPCUAError if browse operation fails
    public func browse(nodeValues: [NodeValue]) async throws -> [BrowseResult] {
        try await browse(nodeValues: nodeValues).get()
    }
    
    /// Reads values from nodes on the OPC UA server using async/await.
    /// - Parameter nodes: Array of nodes to read
    /// - Returns: Array of data values
    /// - Throws: OPCUAError if read operation fails
    public func read(nodes: [ReadValue]) async throws -> [DataValue] {
        try await read(nodes: nodes).get()
    }

    /// Reads values from nodes on the OPC UA server using value-based node identifiers.
    /// - Parameters:
    ///   - nodeValues: Array of node values to read
    ///   - attributeId: OPC UA attribute to read (defaults to Value)
    ///   - dataEncoding: Optional data encoding descriptor
    /// - Returns: Array of data values
    /// - Throws: OPCUAError if read operation fails
    public func read(
        nodeValues: [NodeValue],
        attributeId: UInt32 = 0x0000000d,
        dataEncoding: QualifiedName = QualifiedName()
    ) async throws -> [DataValue] {
        try await read(nodeValues: nodeValues, attributeId: attributeId, dataEncoding: dataEncoding).get()
    }
    
    /// Writes values to nodes on the OPC UA server using async/await.
    /// - Parameter nodes: Array of write values
    /// - Returns: Array of status codes indicating success/failure for each write
    /// - Throws: OPCUAError if write operation fails
    public func write(nodes: [WriteValue]) async throws -> [StatusCodes] {
        try await write(nodes: nodes).get()
    }

    /// Writes values to nodes on the OPC UA server using value-based node identifiers.
    /// - Parameters:
    ///   - nodeValues: Array of node values to write to
    ///   - values: Array of payloads matching `nodeValues` by index
    ///   - attributeId: OPC UA attribute to write (defaults to Value)
    /// - Returns: Array of status codes indicating success/failure for each write
    /// - Throws: OPCUAError if write operation fails
    public func write(
        nodeValues: [NodeValue],
        values: [DataValue],
        attributeId: UInt32 = 0x0000000d
    ) async throws -> [StatusCodes] {
        try await write(nodeValues: nodeValues, values: values, attributeId: attributeId).get()
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
            let registration = Task {
                await self.asyncObservers.addDataChangeContinuation(continuation)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    let id = await registration.value
                    await self.asyncObservers.removeDataChangeContinuation(id)
                }
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
            let registration = Task {
                await self.asyncObservers.addErrorContinuation(continuation)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    let id = await registration.value
                    await self.asyncObservers.removeErrorContinuation(id)
                }
            }
        }
    }
}
