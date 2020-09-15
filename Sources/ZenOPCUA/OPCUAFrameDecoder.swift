//
//  OPCUAFrameDecoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import NIO

final class OPCUAFrameDecoder: ByteToMessageDecoder {
    public typealias InboundOut = OPCUAFrame
    private var fragments: ByteBuffer? = nil
    
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState  {
        guard buffer.readableBytes >= 8 else { return .needMoreData }

        let lenght = Int(UInt32(bytes: buffer.getBytes(at: 4, length: 4)!))
        guard buffer.readableBytes >= lenght else { return .needMoreData }

        if let chunkType = ChunkTypes(rawValue: buffer.getString(at: 3, length: 1)!), chunkType == .part {
            if fragments == nil {
                fragments = context.channel.allocator.buffer(capacity: lenght)
            }
            
            let count = buffer.readableBytes / lenght
            var index = 0
            for _ in 0..<count {
                let b = buffer.getBytes(at: index, length: lenght)!
                fragments!.writeBytes(b[24...])
                index += lenght
            }
            
            let bytes = buffer.getBytes(at: index, length: buffer.readableBytes - index)!
            buffer.clear()
            buffer.writeBytes(bytes)

            guard bytes.count > 0, ChunkTypes(rawValue: String(bytes: [bytes[3]], encoding: .utf8)!)! == .frame else {
                return .needMoreData
            }
        }

        if var f = fragments {
            f.writeBytes(buffer.getBytes(at: 24, length: buffer.readableBytes - 24)!)
            let bytes = buffer.getBytes(at: 0, length: 24)!
            buffer.clear()
            buffer.writeBytes(bytes)
            buffer.writeBuffer(&f)
            f.clear()
            fragments = nil
        }
        
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
        guard let type = MessageTypes(rawValue: buffer.getString(at: 0, length: 3)!) else { return nil }
        
        var head = OPCUAFrameHead()
        head.messageType = type
        head.chunkType = ChunkTypes(rawValue: buffer.getString(at: 3, length: 1)!)!
        head.messageSize = UInt32(bytes: buffer.getBytes(at: 4, length: 4)!)
        let bytes = buffer.getBytes(at: 8, length: buffer.readableBytes - 8) ?? [UInt8]()
        
        return OPCUAFrame(head: head, body: bytes)
    }
}
