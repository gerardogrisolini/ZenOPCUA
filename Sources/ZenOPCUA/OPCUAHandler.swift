//
//  OPCUAHandler.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO


public typealias OPCUADataChanged = ([DataChange]) -> ()
public typealias OPCUAHandlerRemoved = () -> ()
public typealias OPCUAErrorCaught = (Error) -> ()

public protocol Promisable { }
public struct Empty: Promisable { }
extension UInt32: Promisable { }
extension Array: Promisable where Element : Promisable { }


final class OPCUAHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = OPCUAFrame
    public typealias OutboundOut = OPCUAFrame

    public var dataChanged: OPCUADataChanged? = nil
    public var handlerRemoved: OPCUAHandlerRemoved? = nil
    public var errorCaught: OPCUAErrorCaught? = nil

    public var sessionActive: CreateSessionResponse? = nil
    public var promises = Dictionary<UInt32, EventLoopPromise<Promisable>>()
    
    var endpoint: String = ""
    var username: String? = nil
    var password: String? = nil
    var messageSecurityMode: MessageSecurityMode = .none
    var securityPolicy: SecurityPolicyUri = .none
    var senderCertificate: String? = nil
    var receiverCertificateThumbprint: String? = nil
    var requestedLifetime: UInt32 = 600000

    public init() {
    }

    public func channelActive(context: ChannelHandlerContext) {
        print("OPCUA Client connected to \(context.remoteAddress!)")
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        
        switch frame.head.messageType {
        case .acknowledge:
            openSecureChannel(context: context)
        case .openChannel:
            let response = OpenSecureChannelResponse(bytes: frame.body)
            print("Opened SecureChannel with SecurityPolicy \(response.securityPolicyUri.rawValue)")
            getEndpoints(context: context, response: response)
        case .error:
            let codeId = UInt32(bytes: frame.body[0...3])
            var error = "error code: \(codeId)"
            if let err = ErrorResponse(rawValue: codeId) {
                error = "\(err)"
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

                print("Found \(sessionActive!.serverEndpoints.count) endpoints")
                if let item = sessionActive!.serverEndpoints.first(where: { $0.messageSecurityMode == messageSecurityMode }) {
                    print("Found \(item.userIdentityTokens.count) policies")
                    print("Selected Endpoint \(item.endpointUrl)")
                    print("SecurityMode \(item.messageSecurityMode)")

                    var userIdentityToken: UserIdentity
                    if let username = username, let password = password {
                        let policyId = sessionActive!.serverEndpoints.first!.userIdentityTokens.first(where: { $0.tokenType == .userName })!.policyId
                        print("PolicyId \(policyId)")
                        let identityToken = UserIdentityInfoUserName(policyId: policyId, username: username, password: password)
                        userIdentityToken = identityToken
                    } else {
                        let policyId = sessionActive!.serverEndpoints.first!.userIdentityTokens.first(where: { $0.tokenType == .anonymous })!.policyId
                        print("PolicyId \(policyId)")
                        userIdentityToken = AnonymousIdentity(policyId: policyId)
                    }
                    activateSession(context: context, userIdentityToken: userIdentityToken)
                } else {
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
        let chunkSize: Int = 4098

        if frame.head.messageSize > chunkSize {

            var index = 0
            while index < frame.head.messageSize {
                print("\(index) < \(frame.head.messageSize)")
                let part: OPCUAFrame
                if (index + chunkSize - 8) >= frame.head.messageSize {
                    let body = frame.body[index...].map { $0 }
                    part = OPCUAFrame(head: frame.head, body: body)
                } else {
                    let head = OPCUAFrameHead(messageType: frame.head.messageType, chunkType: .part)
                    let body = frame.body[index..<(index + chunkSize - 8)].map { $0 }
                    part = OPCUAFrame(head: head, body: body)
                }
                context.writeAndFlush(self.wrapOutboundOut(part), promise: nil)
                index += chunkSize - 8
            }
            
        } else {
            context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
        }
    }
    
    fileprivate func openSecureChannel(context: ChannelHandlerContext) {
        let head = OPCUAFrameHead(messageType: .openChannel, chunkType: .frame)
        let requestId = nextMessageID()
        let body = OpenSecureChannelRequest(
            messageSecurityMode: messageSecurityMode,
            securityPolicy: securityPolicy,
            userTokenType: .issue,
            senderCertificate: senderCertificate,
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
            endpointUrl: endpoint
        )
        write(context, OPCUAFrame(head: head, body: body.bytes))
    }

    fileprivate func createSession(context: ChannelHandlerContext, response: GetEndpointsResponse) {
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let requestId = nextMessageID()
        let body = CreateSessionRequest(
            secureChannelId: response.secureChannelId,
            tokenId: response.tokenId,
            sequenceNumber: requestId,
            requestId: requestId,
            requestHandle: response.requestId,
            endpointUrl: response.endpoints.first!.endpointUrl
        )
        write(context, OPCUAFrame(head: head, body: body.bytes))
    }

    fileprivate func activateSession(context: ChannelHandlerContext, userIdentityToken: UserIdentity) {
        guard  let session = sessionActive else { return }
        
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let requestId = nextMessageID()
        let body = ActivateSessionRequest(
            sequenceNumber: requestId,
            requestId: requestId,
            session: session,
            userIdentityToken: userIdentityToken
        )
        write(context, OPCUAFrame(head: head, body: body.bytes))
    }
    
    private var messageID = UInt32(1)
    
    public func nextMessageID() -> UInt32 {
        messageID += 1
        return messageID
    }
}

