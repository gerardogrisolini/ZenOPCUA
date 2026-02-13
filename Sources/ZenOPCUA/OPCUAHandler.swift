//
//  state.swift
//
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO

public typealias OPCUADataChanged = @Sendable ([DataChange]) -> Void
public typealias OPCUAHandlerChange = @Sendable () -> Void
public typealias OPCUAErrorCaught = @Sendable (Error) -> Void

public protocol Promisable: Sendable { }
public struct Empty: Promisable { }


// Concurrency: confined to the channel's EventLoop.
final class OPCUAHandler: @unchecked Sendable {
    typealias FrameSender = @Sendable (OPCUAFrame) -> Void

    public var promises = Dictionary<UInt32, EventLoopPromise<Promisable>>()
//    public var readRequests = Dictionary<UInt32, [ReadValue]>()
//    public var lastReadRequestId: UInt32? = nil

    public var dataChanged: OPCUADataChanged? = nil
    public var handlerActivated: OPCUAHandlerChange? = nil
    public var handlerRemoved: OPCUAHandlerChange? = nil
    public var errorCaught: OPCUAErrorCaught? = nil
    
    let state: OPCUAConnectionState
    private var sendFrame: FrameSender? = nil
    private var eventLoop: EventLoop? = nil
    
    var tokenId: UInt32 = 0
    var secureChannelId: UInt32 = 0
    var authenticationToken: Node? = nil

    var endpointUrl: String = ""
    var applicationName: String = ""
    var username: String? = nil
    var password: String? = nil
    var certificate: String? = nil
    var privateKey: String? = nil
    var requestedLifetime: UInt32 = 0
    
    
    public init(state: OPCUAConnectionState = OPCUAConnectionState()) {
        self.state = state
    }

    public func activate(on eventLoop: EventLoop, sendFrame: @escaping FrameSender) {
        self.eventLoop = eventLoop
        self.sendFrame = sendFrame
        // If we have a remote certificate, we're reconnecting with security
        // Set isFirstConnection = false so messages are signed/encrypted
        if state.hasRemoteCertificate {
            state.isFirstConnection = false
        }
        
        sendHello()
    }
    
    fileprivate func sendHello() {
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
            
            tokenId = securityToken.tokenId
            secureChannelId = response.secureChannelId
            requestedLifetime = securityToken.revisedLifetime
            if authenticationToken == nil {
                if response.serverNonce.count > 1 {
                    RSACrypto.generateSecurityKeys(
                        serverNonce: response.serverNonce,
                        clientNonce: state.securityPolicy.clientNonce,
                        symmetricSignatureKeySize: state.securityPolicy.symmetricSignatureKeySize,
                        symmetricEncryptionKeySize: state.securityPolicy.symmetricEncryptionKeySize,
                        symmetricBlockSize: state.securityPolicy.symmetricBlockSize,
                        keyDerivationAlgorithm: state.securityPolicy.keyDerivationAlgorithm
                    )
                    state.hasSymmetricKeys = true  // Mark that we now have symmetric keys
                } else {
                }
                getEndpoints(response: response)
            }
        case .error:
            var error: Error
            let code = UInt32(bytes: frame.body[0...3])
            if let status = StatusCodes(rawValue: code),
               (status == .UA_STATUSCODE_BADSECURITYCHECKSFAILED || status == .UA_STATUSCODE_BADUNEXPECTEDERROR),
               state.messageSecurityMode == .sign,
               !state.includeServerThumbprintInOpn,
               !state.opnThumbprintRetryDone {
                state.opnThumbprintRetryDone = true
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
            promises.forEach { key, promise in
                if key != 0 {
                    promise.fail(error)
                }
            }
        default:
            guard let method = Methods(rawValue: UInt16(bytes: frame.body[18..<20])) else { return }

            switch method {
            case .getEndpointsResponse:
                if !createSession(response: GetEndpointsResponse(bytes: frame.body)) {
                    state.reconnect = false
                    let error = OPCUAError.generic("No suitable UserTokenPolicy found for the possible endpoints")
                    failConnectIfPending(error)
                    onErrorCaught(error: error)
                }
            case .createSessionResponse:
                let response = CreateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult != .UA_STATUSCODE_GOOD {
                    state.reconnect = false
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    failConnectIfPending(error)
                    onErrorCaught(error: error)
                } else {
                    activateSession(response: response)
                }
            case .activateSessionResponse:
                let response = ActivateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
                    state.isAcknowledge = false
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
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .readResponse:
                let response = ReadResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .writeResponse:
                let response = WriteResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .createSubscriptionResponse:
                let response = CreateSubscriptionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
//                    print("revisedLifetimeCount: \(response.revisedLifetimeCount)")
//                    print("revisedMaxKeepAliveCount: \(response.revisedMaxKeepAliveCount)")
//                    print("revisedPubliscingInterval: \(response.revisedPubliscingInterval)")
                    promises[response.responseHeader.requestHandle]?.succeed(response)
                } else {
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    promises[response.responseHeader.requestHandle]!.fail(error)
                    onErrorCaught(error: error)
                }
            case .createMonitoredItemsResponse:
                let response = CreateMonitoredItemsResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .deleteSubscriptionsResponse:
                let response = DeleteSubscriptionsResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .publishResponse:
                let response = PublishResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
                    promises[response.responseHeader.requestHandle]?.succeed(response.subscriptionId)
                    guard let dataChanged = dataChanged else { return }
                    dataChanged(response.notificationMessage.notificationData)
                } else {
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    promises[response.responseHeader.requestHandle]!.fail(error)
                    onErrorCaught(error: error)
                }
            case .serviceFault:
                let part = frame.body[20...43].map { $0 }
                let responseHeader = ResponseHeader(bytes: part)

                let error = OPCUAError.code(responseHeader.serviceResult)
                if let promise = promises[responseHeader.requestHandle] {
                    promise.fail(error)
                } else {
                    failConnectIfPending(error)
                }
                onErrorCaught(error: error)
            default:
                break
            }
        }
    }
    
    public func onHandlerActivated() {
        guard let handlerActivated = handlerActivated else { return }
        handlerActivated()
    }

    public func notifyHandlerRemoved() {
        guard let handlerRemoved = handlerRemoved else { return }
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
            securityPolicy: state.securityPolicy
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
        guard let errorCaught = errorCaught else { return }
        errorCaught(error)
    }
    
    private func openSecureChannel() {
        // If we want security but don't have the server certificate yet,
        // first open a non-secure channel to get the endpoints
        let securityMode: MessageSecurityMode
        if state.isAcknowledgeSecure {
            securityMode = .none
        } else {
            securityMode = state.messageSecurityMode
        }


        let head = OPCUAFrameHead(messageType: .openChannel, chunkType: .frame)
        let requestSecureChannelId: UInt32
        let requestTokenType: SecurityTokenRequestType
        if state.isUpgradingToSecure {
            requestSecureChannelId = 0
            requestTokenType = .issue
        } else {
            requestSecureChannelId = secureChannelId
            requestTokenType = secureChannelId > 0 ? .renew : .issue
        }
        let body = OpenSecureChannelRequest(
            messageSecurityMode: securityMode,
            securityPolicy: state.securityPolicy,
            userTokenType: requestTokenType,
            serverCertificate: state.securityPolicy.remoteCertificate,
            requestedLifetime: requestedLifetime,
            requestId: nextMessageID(),
            secureChannelId: requestSecureChannelId,
            includeServerThumbprintInOpn: state.includeServerThumbprintInOpn
        )
        
        let frame = OPCUAFrame(head: head, body: body.bytes)
        send(frame)
    }

    fileprivate func closeSecureChannel(response: CloseSessionResponse) {
        let head = OPCUAFrameHead(messageType: .closeChannel, chunkType: .frame)
        let body = CloseSecureChannelRequest(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: nextMessageID(),
            requestHandle: response.requestId,
            authenticationToken: authenticationToken ?? NodeId()
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        let requestId = response.requestId
        
        send(frame)
        promises[requestId]?.succeed(Empty())
    }

    fileprivate func getEndpoints(response: OpenSecureChannelResponse) {
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let body = GetEndpointsRequest(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: nextMessageID(),
            requestHandle: response.requestId,
            endpointUrl: endpointUrl
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)

        send(frame)
    }
    
    private func verifyServerCertificateThumbprint(_ certificate: [UInt8], context: String) -> Bool {
        guard !certificate.isEmpty else { return true }
        let thumbprint = RSACrypto.sha1(data: Data(certificate))
        if let expected = state.expectedServerThumbprint, expected != thumbprint {
            state.reconnect = false
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

    fileprivate func createSession(response: GetEndpointsResponse) -> Bool {
        let needsSecureUpgrade = state.isAcknowledgeSecure

        guard let endpoint = response
                .endpoints
                .first(where: {
                    $0.messageSecurityMode == state.messageSecurityMode
                    && $0.securityPolicyUri == state.securityPolicy.securityPolicyUri
                })
        else { return false }

        guard verifyServerCertificateThumbprint(endpoint.serverCertificate, context: "GetEndpoints") else {
            return false
        }

        let requestId = nextMessageID()
        let frame: OPCUAFrame

        if needsSecureUpgrade {
            // Load the remote certificate but DON'T set isFirstConnection = false yet
            // We need to send CloseSecureChannelRequest as an unsigned message
            // because the current connection is still using SecurityPolicy#None
            if !endpoint.serverCertificate.isEmpty {
                state.securityPolicy.loadRemoteCertificate(data: endpoint.serverCertificate)
            }
            // Keep isFirstConnection = true so the CloseSecureChannel is sent unsigned
            
            state.isUpgradingToSecure = true
            let head = OPCUAFrameHead(messageType: .closeChannel, chunkType: .frame)
            let body = CloseSecureChannelRequest(
                secureChannelId: secureChannelId,
                tokenId: tokenId,
                requestId: requestId,
                requestHandle: response.requestId,
                authenticationToken: authenticationToken ?? NodeId()
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        } else {
            if !endpoint.serverCertificate.isEmpty && state.securityPolicy.remoteCertificate.isEmpty {
                state.securityPolicy.loadRemoteCertificate(data: endpoint.serverCertificate)
            }
            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CreateSessionRequest(
                secureChannelId: secureChannelId,
                tokenId: tokenId,
                requestId: requestId,
                requestHandle: response.requestId,
                serverUri: endpoint.server.applicationUri,
                endpointUrl: endpointUrl,
                applicationName: applicationName,
                securityPolicy: state.securityPolicy
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        }
        send(frame)

        return true
    }

    fileprivate func activateSession(response: CreateSessionResponse) {
        authenticationToken = response.authenticationToken

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
            guard let eventLoop = eventLoop else { return }
            eventLoop.scheduleRepeatedTask(initialDelay: time, delay: time, notifying: nil) { [weak self] _ in
                guard let self = self else { return }
                self.openSecureChannel()
            }
        } else {
            state.reconnect = false
            let availableModes = response.serverEndpoints.map { String(describing: $0.messageSecurityMode) }.joined(separator: ",")
            let error = OPCUAError.generic(
                "No endpoint for requested security mode \(state.messageSecurityMode). Available modes: [\(availableModes)]"
            )
            failConnectIfPending(error)
            onErrorCaught(error: error)
        }
    }
    
    private var messageID = UInt32(1)
    
    public func resetMessageID() {
        messageID = 0
    }

    public func nextMessageID() -> UInt32 {
        messageID += 1
        return messageID
    }

    func succeedConnectIfPending() {
        guard let promise = promises.removeValue(forKey: 0) else { return }
        promise.succeed(Empty())
    }

    func failConnectIfPending(_ error: Error) {
        guard let promise = promises.removeValue(forKey: 0) else { return }
        promise.fail(error)
    }
    
    public func resetAll() {
        messageID = 0
        secureChannelId = 0
        authenticationToken = nil
        // Don't reset isFirstConnection if we have remote certificate
        // (it means we're reconnecting for the second phase with security)
        if !state.hasRemoteCertificate {
            state.isFirstConnection = true
        }
        state.hasSymmetricKeys = false  // Reset symmetric keys flag
        state.opnThumbprintRetryDone = false
        state.resetSequenceNumber()
    }

    private func send(_ frame: OPCUAFrame) {
        sendFrame?(frame)
    }
}
