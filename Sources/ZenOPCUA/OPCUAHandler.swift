//
//  OPCUAHandler.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO
import CryptoKit

public typealias OPCUADataChanged = ([DataChange]) -> ()
public typealias OPCUAHandlerRemoved = () -> ()
public typealias OPCUAErrorCaught = (Error) -> ()

public protocol Promisable { }
public struct Empty: Promisable { }


final class OPCUAHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = OPCUAFrame
    public typealias OutboundOut = OPCUAFrame

    public var dataChanged: OPCUADataChanged? = nil
    public var handlerRemoved: OPCUAHandlerRemoved? = nil
    public var errorCaught: OPCUAErrorCaught? = nil

    public var sessionActive: CreateSessionResponse? = nil
    public var promises = Dictionary<UInt32, EventLoopPromise<Promisable>>()
    
    var endpoint: EndpointDescription = EndpointDescription()
    var applicationName: String = ""
    var username: String? = nil
    var password: String? = nil
    var messageSecurityMode: MessageSecurityMode = .invalid
    var securityPolicy: SecurityPolicies = .invalid
    var certificate: String? = nil
    var privateKey: String? = nil
    var requestedLifetime: UInt32 = 600000
    var maxRequestMessageSize: Int = 4128

    public init() {
    }

    public func channelActive(context: ChannelHandlerContext) {
        print("OPCUA Client connected to \(context.remoteAddress!)")
        sendHello(context: context)        
    }
    
    fileprivate func sendHello(context: ChannelHandlerContext) {
        let head = OPCUAFrameHead(messageType: .hello, chunkType: .frame)
        let body = Hello(endpointUrl: endpoint.endpointUrl)
        print("hello")
        let frame = OPCUAFrame(head: head, body: body.bytes)
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        
        switch frame.head.messageType {
        case .acknowledge:
            openSecureChannel(context: context)
        case .openChannel:
            let response = OpenSecureChannelResponse(bytes: frame.body)
            print("Opened SecureChannel with SecurityPolicy \(response.securityPolicyUri)")
            getEndpoints(context: context, response: response)
        case .error:
            var error = UInt32(bytes: frame.body[0...3]).description
            if frame.body.count > 8, let reason = String(bytes: frame.body[8...], encoding: .utf8) {
                error = reason
            }
            errorCaught(context: context, error: OPCUAError.generic(error))
        default:
            guard let method = Methods(rawValue: UInt16(bytes: frame.body[18..<20])) else { return }
            //print(method)
            switch method {
            case .getEndpointsResponse:
                createSession(context: context, response: GetEndpointsResponse(bytes: frame.body))
            case .createSessionResponse:
                sessionActive = CreateSessionResponse(bytes: frame.body)
                if sessionActive!.maxRequestMessageSize > 0 {
                    maxRequestMessageSize = Int(sessionActive!.maxRequestMessageSize)
                }
                if !activateSession(context: context) {
                    promises[0]!.fail(OPCUAError.generic("No suitable UserTokenPolicy found for the possible endpoints"))
                }
            case .activateSessionResponse:
                let response = ActivateSessionResponse(bytes: frame.body)
                if response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD {
                    promises[0]!.succeed(Empty())
                } else {
                    promises[0]!.fail(OPCUAError.code(response.responseHeader.serviceResult))
                }
            case .closeSessionResponse:
                closeSecureChannel(context: context, response: CloseSessionResponse(bytes: frame.body))
            case .browseResponse:
                let response = BrowseResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(response.results)
            case .readResponse:
                let response = ReadResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(response.results)
            case .writeResponse:
                let response = WriteResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(response.results)
            case .createSubscriptionResponse:
                let response = CreateSubscriptionResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(response.subscriptionId)
            case .createMonitoredItemsResponse:
                let response = CreateMonitoredItemsResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(response.results)
            case .deleteSubscriptionsResponse:
                let response = DeleteSubscriptionsResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(response.results)
            case .publishResponse:
                let response = PublishResponse(bytes: frame.body)
                guard let dataChanged = dataChanged else { return }
                dataChanged(response.notificationMessage.notificationData)
            default:
                break
            }
        }
    }
    
    public func handlerRemoved(context: ChannelHandlerContext) {
        guard let handlerRemoved = handlerRemoved else { return }
        handlerRemoved()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)

        guard let errorCaught = errorCaught else { return }
        errorCaught(error)
    }

    fileprivate func write(_ context: ChannelHandlerContext, _ frame: OPCUAFrame) {
        if frame.head.messageSize > maxRequestMessageSize {
            var index = 0
            while index < frame.head.messageSize {
                print("\(index) < \(frame.head.messageSize)")
                let part: OPCUAFrame
                if (index + maxRequestMessageSize - 8) >= frame.head.messageSize {
                    let body = frame.body[index...].map { $0 }
                    part = OPCUAFrame(head: frame.head, body: body)
                } else {
                    let head = OPCUAFrameHead(messageType: .message, chunkType: .part)
                    let body = frame.body[index..<(index + maxRequestMessageSize - 8)].map { $0 }
                    part = OPCUAFrame(head: head, body: body)
                }
                context.writeAndFlush(self.wrapOutboundOut(part), promise: nil)
                index += maxRequestMessageSize - 8
            }
        } else {
            context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
        }
    }
    
    fileprivate func openSecureChannel(context: ChannelHandlerContext) {
        var securityMode = messageSecurityMode
        var policy = securityPolicy
        var userTokenType: SecurityTokenRequestType = sessionActive == nil ? .issue : .renew
        var receiverCertificateThumbprint: [UInt8] = []
        
        if certificate != nil {
            if endpoint.serverCertificate.count > 0 {
                userTokenType = .renew
                let digest = Insecure.SHA1.hash(data: endpoint.serverCertificate)
                receiverCertificateThumbprint.append(contentsOf: digest.data)
            } else {
                securityMode = .none
                policy = .none
            }
        }
        
        let head = OPCUAFrameHead(messageType: .openChannel, chunkType: .frame)
        let requestId = nextMessageID()
        let body = OpenSecureChannelRequest(
            messageSecurityMode: securityMode,
            securityPolicy: policy,
            userTokenType: userTokenType,
            senderCertificate: certificate,
            receiverCertificateThumbprint: receiverCertificateThumbprint,
            requestedLifetime: requestedLifetime,
            requestId: requestId
        )
        
        write(context, OPCUAFrame(head: head, body: body.bytes))
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
            endpointUrl: endpoint.endpointUrl
        )
        write(context, OPCUAFrame(head: head, body: body.bytes))
    }

    fileprivate func createSession(context: ChannelHandlerContext, response: GetEndpointsResponse) {
        let requestId = nextMessageID()
        let frame: OPCUAFrame
        
        if certificate != nil && endpoint.serverCertificate.count == 0 {
            endpoint = response.endpoints.first(where: { $0.messageSecurityMode == messageSecurityMode })!

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
            endpoint = response.endpoints.first(where: { $0.messageSecurityMode == messageSecurityMode })!

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let body = CreateSessionRequest(
                secureChannelId: response.secureChannelId,
                tokenId: response.tokenId,
                sequenceNumber: requestId,
                requestId: requestId,
                requestHandle: response.requestId,
                serverUri: endpoint.server.applicationUri,
                endpointUrl: endpoint.endpointUrl,
                applicationName: applicationName,
                clientCertificate: certificate,
                securityPolicyUri: endpoint.securityPolicyUri
            )
            frame = OPCUAFrame(head: head, body: body.bytes)
        }

        write(context, frame)
    }

    fileprivate func activateSession(context: ChannelHandlerContext) -> Bool {
        guard  let session = sessionActive else { return false }
        
        print("Found \(sessionActive!.serverEndpoints.count) endpoints")
        
        if let item = session.serverEndpoints.first(where: {
            $0.messageSecurityMode == messageSecurityMode && $0.endpointUrl == endpoint.endpointUrl
        }) {
            print("Found \(item.userIdentityTokens.count) policies")
            print("Selected Endpoint \(item.endpointUrl)")
            print("SecurityMode \(item.messageSecurityMode)")
            var userIdentityInfo: UserIdentityInfo
            let serverEndpoint = session.serverEndpoints.first!
            if let certificate = certificate, let privateKey = privateKey {
                let policy = serverEndpoint.userIdentityTokens.first(where: { $0.tokenType == .certificate })!
                userIdentityInfo = UserIdentityInfoX509(
                    policyId: policy.policyId,
                    certificate: certificate,
                    privateKey: privateKey,
                    serverCertificate: session.serverCertificate,
                    serverNonce: session.serverNonce,
                    securityPolicyUri: policy.securityPolicyUri!
                )
            } else if let username = username, let password = password {
                let policy = serverEndpoint.userIdentityTokens.first(where: { $0.tokenType == .userName })!
                userIdentityInfo = UserIdentityInfoUserName(
                    policyId: policy.policyId,
                    username: username,
                    password: password,
                    serverCertificate: session.serverCertificate,
                    serverNonce: session.serverNonce,
                    securityPolicyUri: policy.securityPolicyUri
                )
            } else {
                let policyId = serverEndpoint.userIdentityTokens.first(where: { $0.tokenType == .anonymous })!.policyId
                userIdentityInfo = UserIdentityInfoAnonymous(policyId: policyId)
            }
            print("PolicyId \(userIdentityInfo.policyId)")

            let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
            let requestId = nextMessageID()
            let body = ActivateSessionRequest(
                sequenceNumber: requestId,
                requestId: requestId,
                session: session,
                userIdentityInfo: userIdentityInfo
            )
            write(context, OPCUAFrame(head: head, body: body.bytes))
            
            return true
        }
        
        return false
    }
    
    private var messageID = UInt32(1)
    
    public func nextMessageID() -> UInt32 {
        messageID += 1
        return messageID
    }
}

