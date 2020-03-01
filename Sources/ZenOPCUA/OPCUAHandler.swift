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
    
    public init() {
    }

    public func channelActive(context: ChannelHandlerContext) {
        print("OPCUA Client connected to \(context.remoteAddress!)")
        print("SecurityPolicy not specified -> use default #None")
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
                activateSession(context: context)
                print("Found \(sessionActive?.serverEndpoints.count ?? 0) endpoints")
                if let item = sessionActive?.serverEndpoints.first {
                    print("Found \(item.userIdentityTokens.count) policies")
                    print("Selected Endpoint \(item.endpointUrl) with SecurityMode \(item.messageSecurityMode == 1 ? "None" : "UserToken") and PolicyId \(item.userIdentityTokens.first!.policyId)")
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

    fileprivate func openSecureChannel(context: ChannelHandlerContext) {
        let head = OPCUAFrameHead(messageType: .openChannel, chunkType: .frame)
        let body = OpenSecureChannelRequest(secureChannelId: 0)
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
            endpointUrl: "opc.tcp://\(ZenOPCUA.host):\(ZenOPCUA.port)/OPCUA/SimulationServer"
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
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
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }

    fileprivate func activateSession(context: ChannelHandlerContext) {
        guard  let session = sessionActive else { return }
        
        let head = OPCUAFrameHead(messageType: .message, chunkType: .frame)
        let requestId = nextMessageID()
        let body = ActivateSessionRequest(
            sequenceNumber: requestId,
            requestId: requestId,
            session: session
        )
        let frame = OPCUAFrame(head: head, body: body.bytes)
        
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }
    
    private var messageID = UInt32(1)
    
    public func nextMessageID() -> UInt32 {
        messageID += 1
        return messageID
    }
}

