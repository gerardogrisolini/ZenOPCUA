//
//  OPCUAHandler.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO

public typealias OPCUADataChanged = ([DataChange]) -> ()
public typealias OPCUAHandlerChange = () -> ()
public typealias OPCUAErrorCaught = (Error) -> ()

public protocol Promisable { }
public struct Empty: Promisable { }


final class OPCUAHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = OPCUAFrame
    public typealias OutboundOut = OPCUAFrame

    public var dataChanged: OPCUADataChanged? = nil
    public var handlerActivated: OPCUAHandlerChange? = nil
    public var handlerRemoved: OPCUAHandlerChange? = nil
    public var errorCaught: OPCUAErrorCaught? = nil

    public var sessionActive: CreateSessionResponse? = nil
    public var promises = Dictionary<UInt32, EventLoopPromise<Promisable>>()
    
    static var securityPolicy: SecurityPolicy = SecurityPolicy()
    static var messageSecurityMode: MessageSecurityMode = .none
    static var endpoint: EndpointDescription = EndpointDescription()
    static var bufferSize: Int = 8196
    static var isAcknowledge: Bool = false
    static var isAcknowledgeSecure: Bool = false
    
    var endpointUrl: String = ""
    var applicationName: String = ""
    var username: String? = nil
    var password: String? = nil
    var requestedLifetime: UInt32 = 0

    public init() {
    }

    public func channelActive(context: ChannelHandlerContext) {
        #if DEBUG
        print("OPCUA Client connected to \(context.remoteAddress!)")
        #endif
        sendHello(context: context)        
    }
    
    fileprivate func sendHello(context: ChannelHandlerContext) {
        let head = OPCUAFrameHead(messageType: .hello, chunkType: .frame)
        let body = Hello(endpointUrl: endpointUrl)
        let frame = OPCUAFrame(head: head, body: body.bytes)
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        
        switch frame.head.messageType {
        case .acknowledge:
            OPCUAHandler.bufferSize = Int(Acknowledge(bytes: frame.body).sendBufferSize)
            openSecureChannel(context: context)
        case .openChannel:
            let response = OpenSecureChannelResponse(bytes: frame.body)
            print(response.securityToken.revisedLifetime)
            getEndpoints(context: context, response: response)
        case .error:
            var error: Error
            let code = UInt32(bytes: frame.body[0...3])
            if let status = StatusCodes(rawValue: code) {
                var description = code.description
                if frame.body.count > 8, let reason = String(bytes: frame.body[8...], encoding: .utf8) {
                    description = reason
                }
                error = OPCUAError.code(status, reason: description)
            } else {
                error = OPCUAError.generic(code.description)
            }
            onErrorCaught(context: context, error: error)
            promises.forEach { promise in
                promise.value.fail(error)
            }
        default:
            guard let method = Methods(rawValue: UInt16(bytes: frame.body[18..<20])) else { return }
            //print(method)
            switch method {
            case .getEndpointsResponse:
                if !createSession(context: context, response: GetEndpointsResponse(bytes: frame.body)) {
                    OPCUAHandler.isAcknowledgeSecure = false
                    ZenOPCUA.reconnect = false
                    
                    let error = OPCUAError.generic("No suitable UserTokenPolicy found for the possible endpoints")
                    promises[0]!.fail(error)
                    onErrorCaught(context: context, error: error)
                }
            case .createSessionResponse:
                let response = CreateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult != .UA_STATUSCODE_GOOD {
                    OPCUAHandler.isAcknowledgeSecure = false
                    ZenOPCUA.reconnect = false
                    
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    promises[0]!.fail(error)
                    onErrorCaught(context: context, error: error)
                } else {
                    activateSession(context: context, response: response)
                }
            case .activateSessionResponse:
                let response = ActivateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
                    OPCUAHandler.isAcknowledge = false
                    OPCUAHandler.isAcknowledgeSecure = false
                    promises[0]!.succeed(Empty())
                    onHandlerActivated()
                } else {
                    let error = OPCUAError.code(response.responseHeader.serviceResult)
                    promises[0]!.fail(error)
                    onErrorCaught(context: context, error: error)
                }
            case .closeSessionResponse:
                closeSecureChannel(context: context, response: CloseSessionResponse(bytes: frame.body))
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
                    onErrorCaught(context: context, error: error)
                }
            case .createMonitoredItemsResponse:
                let response = CreateMonitoredItemsResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .deleteSubscriptionsResponse:
                let response = DeleteSubscriptionsResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.results)
            case .publishResponse:
                let response = PublishResponse(bytes: frame.body)
                promises[response.responseHeader.requestHandle]?.succeed(response.subscriptionId)
                guard let dataChanged = dataChanged else { return }
                dataChanged(response.notificationMessage.notificationData)
            case .serviceFault:
                let part = frame.body[20...43].map { $0 }
                let responseHeader = ResponseHeader(bytes: part)
                let error = OPCUAError.code(responseHeader.serviceResult)
                promises[responseHeader.requestHandle]?.fail(error)
                onErrorCaught(context: context, error: error)
            default:
                break
            }
        }
    }
    
    public func onHandlerActivated() {
        guard let handlerActivated = handlerActivated else { return }
        handlerActivated()
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        guard let handlerRemoved = handlerRemoved else { return }
        handlerRemoved()
    }
    
    public func onErrorCaught(context: ChannelHandlerContext, error: Error) {
        guard let errorCaught = errorCaught else { return }
        errorCaught(error)
        
//        context.flush()
//        context.close(mode: .all)
    }
    
    fileprivate func openSecureChannel(context: ChannelHandlerContext) {
        var securityMode = OPCUAHandler.messageSecurityMode
        var userTokenType: SecurityTokenRequestType = .issue
        
        if securityMode != .none {
            if OPCUAHandler.endpoint.serverCertificate.count > 0 {
                OPCUAHandler.isAcknowledgeSecure = false
                userTokenType = .renew
            } else {
                securityMode = .none
            }
        }

        let head = OPCUAFrameHead(messageType: .openChannel, chunkType: .frame)
        let requestId = nextMessageID()
        let body = OpenSecureChannelRequest(
            messageSecurityMode: securityMode,
            securityPolicy: securityMode == .none ? SecurityPolicy() : OPCUAHandler.securityPolicy,
            userTokenType: userTokenType,
            serverCertificate: OPCUAHandler.endpoint.serverCertificate,
            requestedLifetime: requestedLifetime,
            requestId: requestId
        )
        
        let frame = OPCUAFrame(head: head, body: body.bytes)
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }

    fileprivate func closeSecureChannel(context: ChannelHandlerContext, response: CloseSessionResponse) {
        let head = OPCUAFrameHead(messageType: .closeChannel, chunkType: .frame)
        let requestId = nextMessageID()
        let body = CloseSecureChannelRequest(
            secureChannelId: response.secureChannelId,
            tokenId: response.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: response.requestId
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        context.writeAndFlush(self.wrapOutboundOut(frame)).whenComplete { _ in
            self.promises[response.requestId]!.succeed(Empty())
        }
    }

    fileprivate func getEndpoints(context: ChannelHandlerContext, response: OpenSecureChannelResponse) {
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let requestId = nextMessageID()
        let body = GetEndpointsRequest(
            secureChannelId: response.secureChannelId,
            tokenId: response.securityToken.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: response.requestId,
            endpointUrl: endpointUrl
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }

    fileprivate func createSession(context: ChannelHandlerContext, response: GetEndpointsResponse) -> Bool {
        guard let endpoint = response
                .endpoints
                .first(where: {
                    $0.messageSecurityMode == OPCUAHandler.messageSecurityMode
                    && $0.securityPolicyUri == OPCUAHandler.securityPolicy.securityPolicyUri
                })
        else { return false }
        
        OPCUAHandler.endpoint = endpoint
        OPCUAHandler.securityPolicy.loadServerCertificate()

        let requestId = nextMessageID()
        let frame: OPCUAFrame

        if OPCUAHandler.isAcknowledgeSecure {
            let head = OPCUAFrameHead(messageType: .closeChannel, chunkType: .frame)
            let body = CloseSecureChannelRequest(
                secureChannelId: response.secureChannelId,
                tokenId: response.tokenId,
                sequenceNumber: requestId,
                requestId: requestId,
                requestHandle: response.requestId
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        } else {
            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CreateSessionRequest(
                secureChannelId: response.secureChannelId,
                tokenId: response.tokenId,
                sequenceNumber: requestId,
                requestId: requestId,
                requestHandle: response.requestId,
                serverUri: OPCUAHandler.endpoint.server.applicationUri,
                endpointUrl: endpointUrl,
                applicationName: applicationName,
                securityPolicy: OPCUAHandler.securityPolicy
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        }

        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)

        return true
    }

    fileprivate func activateSession(context: ChannelHandlerContext, response: CreateSessionResponse) {
        sessionActive = response
        
        print("Found \(response.serverEndpoints.count) endpoints")
        
        if let endpoint = response.serverEndpoints.first(where: {
            $0.messageSecurityMode == OPCUAHandler.messageSecurityMode && $0.endpointUrl.hasPrefix("opc.tcp")
        }) {
            print("Found \(endpoint.userIdentityTokens.count) policies")
            print("Selected Endpoint \(endpoint.endpointUrl)")
            print("SecurityMode \(endpoint.messageSecurityMode)")

            var userIdentityInfo: UserIdentityInfo
            if OPCUAHandler.securityPolicy.clientCertificate.count > 0 {
                let policy = endpoint.userIdentityTokens.first(where: { $0.tokenType == .certificate })!
                userIdentityInfo = UserIdentityInfoX509(
                    policyId: policy.policyId,
                    certificate: OPCUAHandler.securityPolicy.clientCertificate,
                    serverCertificate: OPCUAHandler.endpoint.serverCertificate,
                    serverNonce: response.serverNonce
                )
            } else if let username = username, let password = password {
                let policy = endpoint.userIdentityTokens.first(where: { $0.tokenType == .userName })!
                userIdentityInfo = UserIdentityInfoUserName(
                    policyId: policy.policyId,
                    username: username,
                    password: password,
                    serverNonce: response.serverNonce,
                    securityPolicyUri: policy.securityPolicyUri
                )
            } else {
                let policyId = endpoint.userIdentityTokens.first(where: { $0.tokenType == .anonymous })!.policyId
                userIdentityInfo = UserIdentityInfoAnonymous(policyId: policyId)
            }
            print("PolicyId \(userIdentityInfo.policyId)")

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let requestId = nextMessageID()
            let body = ActivateSessionRequest(
                sequenceNumber: requestId,
                requestId: requestId,
                session: response,
                userIdentityInfo: userIdentityInfo
            )
            let frame = OPCUAFrame(head: head, body: body.bytes)
            context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
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
}

