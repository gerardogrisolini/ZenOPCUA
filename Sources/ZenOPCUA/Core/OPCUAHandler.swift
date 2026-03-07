//
//  state.swift
//
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO
import NIOConcurrencyHelpers

public typealias OPCUADataChanged = @Sendable ([DataChange]) -> Void
public typealias OPCUAHandlerChange = @Sendable () -> Void
public typealias OPCUAErrorCaught = @Sendable (Error) -> Void

public protocol Promisable: Sendable { }
public struct Empty: Promisable { }

private struct PendingPromiseBox: Sendable {
    let promise: EventLoopPromise<Promisable>
}

private actor PendingPromiseStore {
    private var promises: [UInt32: PendingPromiseBox] = [:]

    func store(_ promise: EventLoopPromise<Promisable>, for requestId: UInt32) {
        promises[requestId] = PendingPromiseBox(promise: promise)
    }

    func take(for requestId: UInt32) -> PendingPromiseBox? {
        promises.removeValue(forKey: requestId)
    }

    func takeAll(excluding excludedRequestId: UInt32? = nil) -> [PendingPromiseBox] {
        let keysToRemove = promises.keys.filter { key in
            key != excludedRequestId
        }
        let removed = keysToRemove.compactMap { key in
            promises.removeValue(forKey: key)
        }
        return removed
    }
}

private actor SecureChannelRenewRuntime {
    private var task: RepeatedTask?

    func replace(with task: RepeatedTask?) {
        if let currentTask = self.task {
            currentTask.cancel()
        }
        self.task = task
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

actor MessageIDRuntime {
    private struct CounterCache: Sendable {
        private let box = NIOLockedValueBox<UInt32>(1)

        func reset() {
            box.withLockedValue { value in
                value = 0
            }
        }

        func next() -> UInt32 {
            box.withLockedValue { value in
                value += 1
                return value
            }
        }
    }

    nonisolated private let cache = CounterCache()

    nonisolated func reset() {
        cache.reset()
    }

    nonisolated func next() -> UInt32 {
        cache.next()
    }
}

actor ChannelSessionRuntime {
    private struct SessionState: Sendable {
        var secureChannelId: UInt32 = 0
        var tokenId: UInt32 = 0
        var authenticationTokenValue: NodeValue?
    }

    private struct SessionCache: Sendable {
        private let box = NIOLockedValueBox(SessionState())

        var currentSecureChannelId: UInt32 {
            box.withLockedValue { state in
                state.secureChannelId
            }
        }

        var currentTokenId: UInt32 {
            box.withLockedValue { state in
                state.tokenId
            }
        }

        var currentAuthenticationTokenValue: NodeValue? {
            box.withLockedValue { state in
                state.authenticationTokenValue
            }
        }

        func update(secureChannelId: UInt32, tokenId: UInt32) {
            box.withLockedValue { state in
                state.secureChannelId = secureChannelId
                state.tokenId = tokenId
            }
        }

        func setAuthenticationTokenValue(_ authenticationTokenValue: NodeValue?) {
            box.withLockedValue { state in
                state.authenticationTokenValue = authenticationTokenValue
            }
        }

        func reset() {
            box.withLockedValue { state in
                state = SessionState()
            }
        }
    }

    nonisolated private let cache = SessionCache()

    nonisolated var currentSecureChannelId: UInt32 {
        cache.currentSecureChannelId
    }

    nonisolated var currentTokenId: UInt32 {
        cache.currentTokenId
    }

    nonisolated var currentAuthenticationTokenValue: NodeValue? {
        cache.currentAuthenticationTokenValue
    }

    nonisolated func update(secureChannelId: UInt32, tokenId: UInt32) {
        cache.update(secureChannelId: secureChannelId, tokenId: tokenId)
    }

    nonisolated func setAuthenticationTokenValue(_ authenticationTokenValue: NodeValue?) {
        cache.setAuthenticationTokenValue(authenticationTokenValue)
    }

    nonisolated func reset() {
        cache.reset()
    }
}

actor HandlerConfigurationRuntime {
    private struct ConfigurationState: Sendable {
        var endpointUrl: String = ""
        var applicationName: String = ""
        var username: String?
        var password: String?
        var certificate: String?
        var privateKey: String?
        var requestedLifetime: UInt32 = 0
    }

    private struct ConfigurationCache: Sendable {
        private let box = NIOLockedValueBox(ConfigurationState())

        var currentEndpointUrl: String {
            box.withLockedValue { state in
                state.endpointUrl
            }
        }

        var currentApplicationName: String {
            box.withLockedValue { state in
                state.applicationName
            }
        }

        var currentUsername: String? {
            box.withLockedValue { state in
                state.username
            }
        }

        var currentPassword: String? {
            box.withLockedValue { state in
                state.password
            }
        }

        var currentCertificate: String? {
            box.withLockedValue { state in
                state.certificate
            }
        }

        var currentPrivateKey: String? {
            box.withLockedValue { state in
                state.privateKey
            }
        }

        var currentRequestedLifetime: UInt32 {
            box.withLockedValue { state in
                state.requestedLifetime
            }
        }

        func updateEndpointUrl(_ endpointUrl: String) {
            box.withLockedValue { state in
                state.endpointUrl = endpointUrl
            }
        }

        func updateApplicationName(_ applicationName: String) {
            box.withLockedValue { state in
                state.applicationName = applicationName
            }
        }

        func updateCredentials(username: String?, password: String?) {
            box.withLockedValue { state in
                state.username = username
                state.password = password
            }
        }

        func updateCertificates(certificate: String?, privateKey: String?) {
            box.withLockedValue { state in
                state.certificate = certificate
                state.privateKey = privateKey
            }
        }

        func updateRequestedLifetime(_ requestedLifetime: UInt32) {
            box.withLockedValue { state in
                state.requestedLifetime = requestedLifetime
            }
        }
    }

    nonisolated private let cache = ConfigurationCache()

    nonisolated var currentEndpointUrl: String {
        cache.currentEndpointUrl
    }

    nonisolated var currentApplicationName: String {
        cache.currentApplicationName
    }

    nonisolated var currentUsername: String? {
        cache.currentUsername
    }

    nonisolated var currentPassword: String? {
        cache.currentPassword
    }

    nonisolated var currentCertificate: String? {
        cache.currentCertificate
    }

    nonisolated var currentPrivateKey: String? {
        cache.currentPrivateKey
    }

    nonisolated var currentRequestedLifetime: UInt32 {
        cache.currentRequestedLifetime
    }

    nonisolated func updateEndpointUrl(_ endpointUrl: String) {
        cache.updateEndpointUrl(endpointUrl)
    }

    nonisolated func updateApplicationName(_ applicationName: String) {
        cache.updateApplicationName(applicationName)
    }

    nonisolated func updateCredentials(username: String?, password: String?) {
        cache.updateCredentials(username: username, password: password)
    }

    nonisolated func updateCertificates(certificate: String?, privateKey: String?) {
        cache.updateCertificates(certificate: certificate, privateKey: privateKey)
    }

    nonisolated func updateRequestedLifetime(_ requestedLifetime: UInt32) {
        cache.updateRequestedLifetime(requestedLifetime)
    }
}

private actor HandlerCallbackRuntime {
    private struct CallbackState: Sendable {
        var dataChanged: OPCUADataChanged?
        var handlerActivated: OPCUAHandlerChange?
        var handlerRemoved: OPCUAHandlerChange?
        var errorCaught: OPCUAErrorCaught?
    }

    private struct CallbackCache: Sendable {
        private let box = NIOLockedValueBox(CallbackState())

        var currentDataChanged: OPCUADataChanged? {
            box.withLockedValue { state in
                state.dataChanged
            }
        }

        var currentHandlerActivated: OPCUAHandlerChange? {
            box.withLockedValue { state in
                state.handlerActivated
            }
        }

        var currentHandlerRemoved: OPCUAHandlerChange? {
            box.withLockedValue { state in
                state.handlerRemoved
            }
        }

        var currentErrorCaught: OPCUAErrorCaught? {
            box.withLockedValue { state in
                state.errorCaught
            }
        }

        func updateDataChanged(_ callback: OPCUADataChanged?) {
            box.withLockedValue { state in
                state.dataChanged = callback
            }
        }

        func updateHandlerActivated(_ callback: OPCUAHandlerChange?) {
            box.withLockedValue { state in
                state.handlerActivated = callback
            }
        }

        func updateHandlerRemoved(_ callback: OPCUAHandlerChange?) {
            box.withLockedValue { state in
                state.handlerRemoved = callback
            }
        }

        func updateErrorCaught(_ callback: OPCUAErrorCaught?) {
            box.withLockedValue { state in
                state.errorCaught = callback
            }
        }
    }

    nonisolated private let cache = CallbackCache()

    nonisolated var currentDataChanged: OPCUADataChanged? {
        cache.currentDataChanged
    }

    nonisolated var currentHandlerActivated: OPCUAHandlerChange? {
        cache.currentHandlerActivated
    }

    nonisolated var currentHandlerRemoved: OPCUAHandlerChange? {
        cache.currentHandlerRemoved
    }

    nonisolated var currentErrorCaught: OPCUAErrorCaught? {
        cache.currentErrorCaught
    }

    nonisolated func updateDataChanged(_ callback: OPCUADataChanged?) {
        cache.updateDataChanged(callback)
    }

    nonisolated func updateHandlerActivated(_ callback: OPCUAHandlerChange?) {
        cache.updateHandlerActivated(callback)
    }

    nonisolated func updateHandlerRemoved(_ callback: OPCUAHandlerChange?) {
        cache.updateHandlerRemoved(callback)
    }

    nonisolated func updateErrorCaught(_ callback: OPCUAErrorCaught?) {
        cache.updateErrorCaught(callback)
    }
}

private actor FrameSenderRuntime {
    private struct SenderState: Sendable {
        var sender: OPCUAHandler.FrameSender?
    }

    private struct SenderCache: Sendable {
        private let box = NIOLockedValueBox(SenderState())

        var currentSender: OPCUAHandler.FrameSender? {
            box.withLockedValue { state in
                state.sender
            }
        }

        func update(_ sender: OPCUAHandler.FrameSender?) {
            box.withLockedValue { state in
                state.sender = sender
            }
        }
    }

    nonisolated private let cache = SenderCache()

    nonisolated var currentSender: OPCUAHandler.FrameSender? {
        cache.currentSender
    }

    nonisolated func update(_ sender: OPCUAHandler.FrameSender?) {
        cache.update(sender)
    }
}


// Concurrency: confined to the channel's EventLoop.
final class OPCUAHandler: Sendable {
    typealias FrameSender = @Sendable (OPCUAFrame) -> Void

    private let pendingPromises = PendingPromiseStore()
    private let callbackRuntime = HandlerCallbackRuntime()

    public var dataChanged: OPCUADataChanged? {
        get { callbackRuntime.currentDataChanged }
        set { callbackRuntime.updateDataChanged(newValue) }
    }

    public var handlerActivated: OPCUAHandlerChange? {
        get { callbackRuntime.currentHandlerActivated }
        set { callbackRuntime.updateHandlerActivated(newValue) }
    }

    public var handlerRemoved: OPCUAHandlerChange? {
        get { callbackRuntime.currentHandlerRemoved }
        set { callbackRuntime.updateHandlerRemoved(newValue) }
    }

    public var errorCaught: OPCUAErrorCaught? {
        get { callbackRuntime.currentErrorCaught }
        set { callbackRuntime.updateErrorCaught(newValue) }
    }
    
    let state: OPCUAConnectionState
    private let connectionCoordinator: ConnectionCoordinator
    private let snapshotProvider: ConnectionCoordinatorSnapshotProvider
    private let frameSenderRuntime = FrameSenderRuntime()
    private let secureChannelRenewRuntime = SecureChannelRenewRuntime()
    private let messageIDRuntime = MessageIDRuntime()
    private let channelSessionRuntime = ChannelSessionRuntime()
    private let configurationRuntime = HandlerConfigurationRuntime()
    
    private(set) var tokenId: UInt32 {
        get { channelSessionRuntime.currentTokenId }
        set { channelSessionRuntime.update(secureChannelId: secureChannelId, tokenId: newValue) }
    }

    private(set) var secureChannelId: UInt32 {
        get { channelSessionRuntime.currentSecureChannelId }
        set { channelSessionRuntime.update(secureChannelId: newValue, tokenId: tokenId) }
    }

    private(set) var authenticationTokenValue: NodeValue? {
        get { channelSessionRuntime.currentAuthenticationTokenValue }
        set { channelSessionRuntime.setAuthenticationTokenValue(newValue) }
    }

    var endpointUrl: String {
        get { configurationRuntime.currentEndpointUrl }
        set { configurationRuntime.updateEndpointUrl(newValue) }
    }

    var applicationName: String {
        get { configurationRuntime.currentApplicationName }
        set { configurationRuntime.updateApplicationName(newValue) }
    }

    var username: String? {
        get { configurationRuntime.currentUsername }
        set { configurationRuntime.updateCredentials(username: newValue, password: password) }
    }

    var password: String? {
        get { configurationRuntime.currentPassword }
        set { configurationRuntime.updateCredentials(username: username, password: newValue) }
    }

    var certificate: String? {
        get { configurationRuntime.currentCertificate }
        set { configurationRuntime.updateCertificates(certificate: newValue, privateKey: privateKey) }
    }

    var privateKey: String? {
        get { configurationRuntime.currentPrivateKey }
        set { configurationRuntime.updateCertificates(certificate: certificate, privateKey: newValue) }
    }

    var requestedLifetime: UInt32 {
        get { configurationRuntime.currentRequestedLifetime }
        set { configurationRuntime.updateRequestedLifetime(newValue) }
    }

    private var coordinatorSnapshot: ConnectionCoordinatorSnapshot {
        snapshotProvider.currentSnapshot
    }

    private var activeEventLoop: EventLoop? {
        coordinatorSnapshot.currentEventLoop
    }
    
    
    public init(
        state: OPCUAConnectionState = OPCUAConnectionState(),
        connectionCoordinator: ConnectionCoordinator,
        snapshotProvider: ConnectionCoordinatorSnapshotProvider
    ) {
        self.state = state
        self.connectionCoordinator = connectionCoordinator
        self.snapshotProvider = snapshotProvider
    }

    public func activate(on eventLoop: EventLoop, sendFrame: @escaping FrameSender) {
        frameSenderRuntime.update(sendFrame)
        // If we have a remote certificate, this transport is already beyond the
        // unsigned bootstrap phase and can secure its OpenSecureChannel traffic.
        if state.hasRemoteCertificate {
            Task { [connectionCoordinator] in
                await connectionCoordinator.markSecuredTransportActive()
            }
        }
        
        sendHello()
    }
    
    private func sendHello() {
        let head = OPCUAFrameHead(messageType: .hello, chunkType: .frame)
        let body = Hello(endpointUrl: endpointUrl)
        let frame = OPCUAFrame(head: head, body: body.bytes)
        send(frame)
    }
    
    public func handleInbound(frame: OPCUAFrame) {
        #if DEBUG
        print(" <-- \(frame.head)")
        #endif
        
        switch frame.head.messageType {
        case .acknowledge:
            state.bufferSize = Int(Acknowledge(bytes: frame.body).sendBufferSize)
            openSecureChannel()
        case .openChannel:
            let response = OpenSecureChannelResponse(bytes: frame.body)
            
            // Check if parsing was successful
            guard let responseHeader = response.responseHeader,
                  let securityToken = response.securityToken else {
                print("Failed to parse OpenSecureChannelResponse - frame.body.count=\(frame.body.count)")
                let error = OPCUAError.generic("Failed to parse OpenSecureChannelResponse")
                failConnectIfPending(error)
                return
            }
            
            guard responseHeader.serviceResult == .UA_STATUSCODE_GOOD else {
                failConnectIfPending(OPCUAError.code(responseHeader.serviceResult, reason: ""))
                return
            }
            
            channelSessionRuntime.update(
                secureChannelId: response.header.secureChannelId,
                tokenId: securityToken.tokenId
            )
            requestedLifetime = securityToken.revisedLifetime
            if authenticationTokenValue == nil {
                if response.serverNonce.count > 1 {
                    let securityKeys = RSACrypto.generateSecurityKeys(
                        serverNonce: response.serverNonce,
                        clientNonce: state.clientNonce,
                        symmetricSignatureKeySize: state.symmetricSignatureKeySize,
                        symmetricEncryptionKeySize: state.symmetricEncryptionKeySize,
                        symmetricBlockSize: state.symmetricBlockSize,
                        keyDerivationAlgorithm: state.keyDerivationAlgorithm
                    )
                    state.setSecurityKeys(securityKeys)
                } else {
                }
                getEndpoints(response: response)
            }
        case .error:
            var error: Error
            let code = UInt32(bytes: frame.body[0...3])
            let coordinatorSnapshot = self.coordinatorSnapshot
            if let status = StatusCodes(rawValue: code),
               (status == .UA_STATUSCODE_BADSECURITYCHECKSFAILED || status == .UA_STATUSCODE_BADUNEXPECTEDERROR),
               state.messageSecurityMode == .sign,
               !state.includeServerThumbprintInOpn,
               !coordinatorSnapshot.hasRetriedOpnThumbprintCompatibility {
                Task { [connectionCoordinator] in
                    await connectionCoordinator.markOpnThumbprintRetryDone()
                }
                state.includeServerThumbprintInOpn = true
                state.resetSequenceNumber()
                resetMessageID()
                openSecureChannel()
                return
            }
            #if DEBUG
            print("ERROR MESSAGE RECEIVED:")
            print("  Status code: 0x\(String(format: "%08X", code)) (\(code))")
            print("  Frame body length: \(frame.body.count) bytes")
            if frame.body.count > 4 {
                // Print additional error info if present
                let hexDump = frame.body.prefix(min(100, frame.body.count)).map { String(format: "%02X", $0) }.joined(separator: " ")
                print("  First bytes: \(hexDump)")
            }
            #endif
            if let status = StatusCodes(rawValue: code) {
                var description = code.description
                if frame.body.count > 8, let reason = String(bytes: frame.body[8...], encoding: .utf8) {
                    description = reason
                    #if DEBUG
                    print("  Error reason from server: \(reason)")
                    #endif
                }
                error = OPCUAError.code(status, reason: description)
            } else {
                error = OPCUAError.generic(code.description)
            }
            onErrorCaught(error: error)
            failConnectIfPending(error)
            failOutstandingPromises(error, excluding: 0)
        default:
            guard let method = Methods(rawValue: UInt16(bytes: frame.body[18..<20])) else { return }

            switch method {
            case .getEndpointsResponse:
                if !createSession(response: GetEndpointsResponse(bytes: frame.body)) {
                    Task { [connectionCoordinator] in
                        await connectionCoordinator.disableReconnect()
                    }
                    let error = OPCUAError.generic("No suitable UserTokenPolicy found for the possible endpoints")
                    failConnectIfPending(error)
                    onErrorCaught(error: error)
                }
            case .createSessionResponse:
                let response = CreateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult != .UA_STATUSCODE_GOOD {
                    Task { [connectionCoordinator] in
                        await connectionCoordinator.disableReconnect()
                    }
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    failConnectIfPending(error)
                    onErrorCaught(error: error)
                } else {
                    activateSession(response: response)
                }
            case .activateSessionResponse:
                let response = ActivateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
                    Task { [connectionCoordinator] in
                        await connectionCoordinator.completeAcknowledge()
                    }
                    succeedConnectIfPending()
                    onHandlerActivated()
                } else {
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    failConnectIfPending(error)
                    onErrorCaught(error: error)
                }
            case .closeSessionResponse:
                closeSecureChannel(response: CloseSessionResponse(bytes: frame.body))
            case .browseResponse:
                let response = BrowseResponse(bytes: frame.body)
                succeedPromiseIfPending(response.responseHeader.requestHandle, with: response.results)
            case .readResponse:
                let response = ReadResponse(bytes: frame.body)
                succeedPromiseIfPending(response.responseHeader.requestHandle, with: response.results)
            case .writeResponse:
                let response = WriteResponse(bytes: frame.body)
                succeedPromiseIfPending(response.responseHeader.requestHandle, with: response.results)
            case .createSubscriptionResponse:
                let response = CreateSubscriptionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
//                    print("revisedLifetimeCount: \(response.revisedLifetimeCount)")
//                    print("revisedMaxKeepAliveCount: \(response.revisedMaxKeepAliveCount)")
//                    print("revisedPubliscingInterval: \(response.revisedPubliscingInterval)")
                    succeedPromiseIfPending(response.responseHeader.requestHandle, with: response)
                } else {
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    failPromiseIfPending(response.responseHeader.requestHandle, error: error)
                    onErrorCaught(error: error)
                }
            case .createMonitoredItemsResponse:
                let response = CreateMonitoredItemsResponse(bytes: frame.body)
                succeedPromiseIfPending(response.responseHeader.requestHandle, with: response.results)
            case .deleteSubscriptionsResponse:
                let response = DeleteSubscriptionsResponse(bytes: frame.body)
                succeedPromiseIfPending(response.responseHeader.requestHandle, with: response.results)
            case .publishResponse:
                let response = PublishResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
                    succeedPromiseIfPending(response.responseHeader.requestHandle, with: response.subscriptionId)
                    guard let dataChanged = callbackRuntime.currentDataChanged else { return }
                    dataChanged(response.notificationMessage.notificationData)
                } else {
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    failPromiseIfPending(response.responseHeader.requestHandle, error: error)
                    onErrorCaught(error: error)
                }
            case .serviceFault:
                let part = frame.body[20...43].map { $0 }
                let responseHeader = ResponseHeader(bytes: part)

                let error = OPCUAError.code(responseHeader.serviceResult)
                failServiceFault(responseHeader.requestHandle, error: error)
                onErrorCaught(error: error)
            default:
                break
            }
        }
    }
    
    public func onHandlerActivated() {
        guard let handlerActivated = callbackRuntime.currentHandlerActivated else { return }
        handlerActivated()
    }

    public func notifyHandlerRemoved() {
        guard let handlerRemoved = callbackRuntime.currentHandlerRemoved else { return }
        handlerRemoved()
    }

    private func sendActivateSession(
        response: CreateSessionResponse,
        userTokenPolicy: UserTokenPolicy?
    ) {
        var userIdentityInfo: UserIdentityInfo
        if let username = username, let password = password, let policy = userTokenPolicy {
            userIdentityInfo = UserIdentityInfoUserName(
                policyId: policy.policyId,
                username: username,
                password: password,
                serverNonce: response.serverNonce,
                serverCertificate: response.serverCertificate,
                securityPolicyUri: policy.securityPolicyUri
            )
        } else {
            let policyId = userTokenPolicy?.policyId ?? "anonymous"
            userIdentityInfo = UserIdentityInfoAnonymous(policyId: policyId)
        }

        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let requestId = nextMessageID()
        let body = ActivateSessionRequest(
            requestId: requestId,
            session: response,
            userIdentityInfo: userIdentityInfo,
            securityPolicy: state.activeSecurityPolicy
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        send(frame)
    }
    
    public func handleError(error: Error) {
        #if DEBUG
        print("Error caught: \(error)")
        #endif
        onErrorCaught(error: error)
    }
    
    public func onErrorCaught(error: Error) {
        guard let errorCaught = callbackRuntime.currentErrorCaught else { return }
        errorCaught(error)
    }
    
    private func openSecureChannel() {
        let head = OPCUAFrameHead(messageType: .openChannel, chunkType: .frame)
        let requestSecureChannelId: UInt32
        let requestTokenType: SecurityTokenRequestType
        let coordinatorSnapshot = self.coordinatorSnapshot
        if coordinatorSnapshot.lifecycleIsUpgradingToSecure {
            requestSecureChannelId = 0
            requestTokenType = .issue
        } else {
            requestSecureChannelId = secureChannelId
            requestTokenType = secureChannelId > 0 ? .renew : .issue
        }
        let body = OpenSecureChannelRequest(
            messageSecurityMode: state.effectiveOpenSecureChannelMode,
            securityPolicy: state.activeSecurityPolicy,
            userTokenType: requestTokenType,
            serverCertificate: state.remoteCertificate,
            requestedLifetime: requestedLifetime,
            requestId: nextMessageID(),
            secureChannelId: requestSecureChannelId,
            includeServerThumbprintInOpn: state.includeServerThumbprintInOpn
        )
        
        let frame = OPCUAFrame(head: head, body: body.bytes)
        send(frame)
    }

    private func closeSecureChannel(response: CloseSessionResponse) {
        let head = OPCUAFrameHead(messageType: .closeChannel, chunkType: .frame)
        let body = CloseSecureChannelRequest(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: nextMessageID(),
            requestHandle: response.header.requestId,
            authenticationTokenValue: authenticationTokenValue ?? .base(identifier: 0)
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        let requestId = response.header.requestId
        
        send(frame)
        succeedPromiseIfPending(requestId, with: Empty())
    }

    private func getEndpoints(response: OpenSecureChannelResponse) {
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = GetEndpointsRequest(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: nextMessageID(),
            requestHandle: response.header.requestId,
            endpointUrl: endpointUrl
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)

        send(frame)
    }
    
    private func verifyServerCertificateThumbprint(_ certificate: [UInt8], context: String) -> Bool {
        guard !certificate.isEmpty else { return true }
        let thumbprint = RSACrypto.sha1(data: Data(certificate))
        if let expected = state.expectedServerThumbprint, expected != thumbprint {
            Task { [connectionCoordinator] in
                await connectionCoordinator.disableReconnect()
            }
            let error = OPCUAError.generic("Server certificate mismatch (\(context))")
            failConnectIfPending(error)
            onErrorCaught(error: error)
            return false
        }
        if state.expectedServerThumbprint == nil {
            state.expectedServerThumbprint = thumbprint
        }
        return true
    }

    private func createSession(response: GetEndpointsResponse) -> Bool {
        let needsSecureUpgrade = state.isAcknowledgeSecure

        guard let endpoint = response
                .endpoints
                .first(where: {
                    $0.messageSecurityMode == state.messageSecurityMode
                    && $0.securityPolicyUri == state.securityPolicyUri
                })
        else { return false }

        guard verifyServerCertificateThumbprint(endpoint.serverCertificate, context: "GetEndpoints") else {
            return false
        }

        let requestId = nextMessageID()
        let frame: OPCUAFrame

        if needsSecureUpgrade {
            // Load the remote certificate, but keep the current transport in the
            // unsigned bootstrap phase until the secure reconnect activates.
            // We still need to send CloseSecureChannelRequest unsigned because
            // the current connection is using SecurityPolicy#None.
            if !endpoint.serverCertificate.isEmpty {
                state.loadRemoteCertificate(endpoint.serverCertificate)
            }
            // Keep the current transport in unsigned bootstrap mode so the
            // CloseSecureChannel is sent unsigned.
            
            Task { [connectionCoordinator] in
                await connectionCoordinator.setUpgradingToSecure(true)
            }
            let head = OPCUAFrameHead(messageType: .closeChannel, chunkType: .frame)
            let body = CloseSecureChannelRequest(
                secureChannelId: secureChannelId,
                tokenId: tokenId,
                requestId: requestId,
                requestHandle: response.header.requestId,
                authenticationTokenValue: authenticationTokenValue ?? .base(identifier: 0)
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        } else {
            if !endpoint.serverCertificate.isEmpty && state.remoteCertificate.isEmpty {
                state.loadRemoteCertificate(endpoint.serverCertificate)
            }
            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CreateSessionRequest(
                secureChannelId: secureChannelId,
                tokenId: tokenId,
                requestId: requestId,
                requestHandle: response.header.requestId,
                serverUri: endpoint.server.applicationUri,
                endpointUrl: endpointUrl,
                applicationName: applicationName,
                securityPolicy: state.activeSecurityPolicy
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        }
        send(frame)

        return true
    }

    private func activateSession(response: CreateSessionResponse) {
        authenticationTokenValue = response.authenticationTokenValue

        guard verifyServerCertificateThumbprint(response.serverCertificate, context: "CreateSessionResponse") else {
            return
        }
        
        if let endpoint = response.serverEndpoints.first(where: {
            $0.messageSecurityMode == state.messageSecurityMode && $0.endpointUrl.hasPrefix("opc.tcp")
        }) {
            guard verifyServerCertificateThumbprint(endpoint.serverCertificate, context: "CreateSessionResponse endpoints") else {
                return
            }
            if let _ = username, let _ = password {
                guard let userPolicy = endpoint.userIdentityTokens.first(where: { $0.tokenType == .userName }) else {
                    let error = OPCUAError.generic("No username UserTokenPolicy available for endpoint")
                    errorCaught?(error)
                    failConnectIfPending(error)
                    return
                }
                sendActivateSession(response: response, userTokenPolicy: userPolicy)
            } else {
                let policyId = endpoint.userIdentityTokens.first(where: { $0.tokenType == .anonymous })?.policyId ?? "anonymous"
                let anonymousPolicy = UserTokenPolicy(
                    policyId: policyId,
                    tokenType: .anonymous,
                    issuedTokenType: nil,
                    issuerEndpointUrl: nil,
                    securityPolicyUri: nil
                )
                sendActivateSession(response: response, userTokenPolicy: anonymousPolicy)
            }

            let time = TimeAmount.milliseconds(Int64(Double(requestedLifetime) * 0.75))
            guard let eventLoop = activeEventLoop else { return }
            let renewTask = eventLoop.scheduleRepeatedTask(initialDelay: time, delay: time, notifying: nil) { [weak self] _ in
                guard let self = self else { return }
                self.openSecureChannel()
            }
            Task { [secureChannelRenewRuntime] in
                await secureChannelRenewRuntime.replace(with: renewTask)
            }
        } else {
            Task { [connectionCoordinator] in
                await connectionCoordinator.disableReconnect()
            }
            let availableModes = response.serverEndpoints.map { String(describing: $0.messageSecurityMode) }.joined(separator: ",")
            let error = OPCUAError.generic(
                "No endpoint for requested security mode \(state.messageSecurityMode). Available modes: [\(availableModes)]"
            )
            failConnectIfPending(error)
            onErrorCaught(error: error)
        }
    }
    
    public func resetMessageID() {
        messageIDRuntime.reset()
    }

    public func nextMessageID() -> UInt32 {
        messageIDRuntime.next()
    }

    public func registerPromise(_ promise: EventLoopPromise<Promisable>, for requestId: UInt32, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        let completion = eventLoop.makePromise(of: Void.self)

        Task { [pendingPromises] in
            await pendingPromises.store(promise, for: requestId)
            eventLoop.execute {
                completion.succeed(())
            }
        }

        return completion.futureResult
    }

    public func failPromiseIfPending(_ requestId: UInt32, error: Error) {
        Task { [pendingPromises] in
            guard let box = await pendingPromises.take(for: requestId) else { return }
            let promise = box.promise
            promise.futureResult.eventLoop.execute {
                promise.fail(error)
            }
        }
    }

    public func succeedPromiseIfPending(_ requestId: UInt32, with value: Promisable) {
        Task { [pendingPromises] in
            guard let box = await pendingPromises.take(for: requestId) else { return }
            let promise = box.promise
            promise.futureResult.eventLoop.execute {
                promise.succeed(value)
            }
        }
    }

    private func failOutstandingPromises(_ error: Error, excluding requestId: UInt32? = nil) {
        Task { [pendingPromises] in
            let boxes = await pendingPromises.takeAll(excluding: requestId)
            for box in boxes {
                let promise = box.promise
                promise.futureResult.eventLoop.execute {
                    promise.fail(error)
                }
            }
        }
    }

    private func failServiceFault(_ requestId: UInt32, error: Error) {
        Task { [pendingPromises, weak self] in
            if let box = await pendingPromises.take(for: requestId) {
                let promise = box.promise
                promise.futureResult.eventLoop.execute {
                    promise.fail(error)
                }
            } else {
                self?.failConnectIfPending(error)
            }
        }
    }

    func succeedConnectIfPending() {
        succeedPromiseIfPending(0, with: Empty())
    }

    func failConnectIfPending(_ error: Error) {
        failPromiseIfPending(0, error: error)
    }
    
    public func resetAll() {
        Task { [secureChannelRenewRuntime] in
            await secureChannelRenewRuntime.cancel()
        }
        messageIDRuntime.reset()
        channelSessionRuntime.reset()
        Task { [connectionCoordinator, hasRemoteCertificate = state.hasRemoteCertificate] in
            await connectionCoordinator.resetUnsignedBootstrapSecurity(hasRemoteCertificate: hasRemoteCertificate)
        }
        state.resetSecurityKeys()
        Task { [connectionCoordinator] in
            await connectionCoordinator.resetOpnThumbprintRetry()
        }
        state.resetSequenceNumber()
    }

    private func send(_ frame: OPCUAFrame) {
        frameSenderRuntime.currentSender?(frame)
    }
}
