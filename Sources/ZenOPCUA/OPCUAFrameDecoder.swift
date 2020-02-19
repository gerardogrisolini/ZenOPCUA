//
//  OPCUAFrameDecoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import NIO

final class OPCUAFrameDecoder: ByteToMessageDecoder {
    public typealias InboundOut = OPCUAFrame

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState  {
        guard buffer.readableBytes >= 8 else { return .needMoreData }

        let lenght = UInt32(littleEndianBytes: buffer.getBytes(at: 4, length: 4)!)
        guard buffer.readableBytes >= lenght else { return .needMoreData }

        if let frame = parse(buffer: buffer) {
            context.fireChannelRead(self.wrapInboundOut(frame))
            buffer.clear()
            return .continue
        } else {
            return .needMoreData
        }
    }

    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        // EOF is not semantic in WebSocket, so ignore this.
        return .needMoreData
    }
    
    public func parse(buffer: ByteBuffer) -> OPCUAFrame? {
        var head = OPCUAFrameHead()
        head.messageType = MessageTypes(rawValue: buffer.getString(at: 0, length: 3)!)!
        head.chunkType = ChunkTypes(rawValue: buffer.getString(at: 3, length: 1)!)!
        head.messageSize = UInt32(littleEndianBytes: buffer.getBytes(at: 4, length: 4)!)
        let bytes = buffer.getBytes(at: 8, length: buffer.readableBytes - 8) ?? [UInt8]()
        
        return OPCUAFrame(head: head, body: bytes)
    }
}
