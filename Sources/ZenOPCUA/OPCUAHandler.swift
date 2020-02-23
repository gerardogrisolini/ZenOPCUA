//
//  OPCUAHandler.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO


public typealias OPCUAMessageReceived = (OPCUAFrame) -> ()
public typealias OPCUAHandlerRemoved = () -> ()
public typealias OPCUAErrorCaught = (Error) -> ()


final class OPCUAHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = OPCUAFrame
    public typealias OutboundOut = OPCUAFrame

    public var messageReceived: OPCUAMessageReceived? = nil
    public var handlerRemoved: OPCUAHandlerRemoved? = nil
    public var errorCaught: OPCUAErrorCaught? = nil

    public var sessionActive: CreateSessionResponse? = nil
    public var promises = Dictionary<UInt32, EventLoopPromise<Void>>()
    
    public init() {
    }

    public func channelActive(context: ChannelHandlerContext) {
        #if DEBUG
        print("OPCUA Client connected to \(context.remoteAddress!)")
        #endif
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        print(frame.head)
        
        switch frame.head.messageType {
        case .acknowledge:
            openSecureChannel(context: context)
        case .openChannel:
            getEndpoints(context: context, response: OpenSecureChannelResponse(bytes: frame.body))
        case .error:
            let codeId = UInt32(littleEndianBytes: frame.body[0...3])
            var error = "error code: \(codeId)"
            if let err = ErrorResponse(rawValue: codeId) {
                error = "\(err)"
            }
            errorCaught(context: context, error: OPCUAError.generic(error))
        default:
            guard let method = Methods(rawValue: UInt16(littleEndianBytes: frame.body[18..<20])) else { return }
            print(method)
            switch method {
            case .getEndpointsResponse:
                createSession(context: context, response: GetEndpointsResponse(bytes: frame.body))
            case .createSessionResponse:
                sessionActive = CreateSessionResponse(bytes: frame.body)
                activateSession(context: context)
            case .activateSessionResponse:
                let response = ActivateSessionResponse(bytes: frame.body)
                print(response.responseHeader.serviceDiagnistics)
            case .closeSessionResponse:
                closeSecureChannel(context: context, response: CloseSessionResponse(bytes: frame.body))
            case .browseResponse:
                let response = BrowseResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(())
                
                response.results.forEach { item in
                    
                    print(item.statusCode)
                    
                    item.references.forEach { ref in
                    
                        print(ref.displayName.text)

                        switch ref.nodeId.encodingMask {
                        case .numeric:
                            print((ref.nodeId as! NodeIdNumeric).identifier)
                            print((ref.nodeId as! NodeIdNumeric).nameSpace)
                        case .string:
                            print((ref.nodeId as! NodeIdString).identifier)
                        default:
                            print((ref.nodeId as! NodeId).identifierNumeric)
                        }
                    }
                }
            case .readResponse:
                let response = ReadResponse(bytes: frame.body)
                promises[response.requestId]?.succeed(())
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
        
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: promises[response.requestId])
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
            endpointUrl: "opc.tcp://\(ZenOPCUA.host):\(ZenOPCUA.port)"
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
            endpointUrl: "opc.tcp://\(ZenOPCUA.host):\(ZenOPCUA.port)"
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

