//
//  OPCUAFrameDecoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import NIO

final class OPCUAFrameDecoder: ByteToMessageDecoder {
    public typealias InboundOut = OPCUAFrame
    private var parts: ByteBuffer? = nil
    
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState  {
        guard buffer.readableBytes >= 8 else { return .needMoreData }

        let lenght = UInt32(bytes: buffer.getBytes(at: buffer.readerIndex + 4, length: 4)!).int
        guard buffer.readableBytes >= lenght else { return .needMoreData }

        if let chunkType = ChunkTypes(rawValue: buffer.getString(at: buffer.readerIndex + 3, length: 1)!), chunkType == .part {
            if parts == nil {
                parts = context.channel.allocator.buffer(capacity: lenght)
                parts!.writeBytes(buffer.getBytes(at: 0, length: 24)!)
            }

            let count = buffer.readableBytes / lenght
            for _ in 0..<count {
                let b = buffer.getBytes(at: buffer.readerIndex, length: lenght)!
                parts!.writeBytes(b[24...])
                buffer.moveReaderIndex(forwardBy: lenght)
            }

            if let chunkType = buffer.getString(at: buffer.readerIndex + 3, length: 1) {
                guard ChunkTypes(rawValue: chunkType)! == .frame else { return .needMoreData }
            }
        }

        if var f = parts {
            if buffer.readerIndex < buffer.writerIndex {
                f.writeBytes(buffer.getBytes(at: buffer.readerIndex + 24, length: buffer.readableBytes - 24)!)
            }

            buffer.clear()
            buffer.writeBytes(f.getBytes(at: 0, length: 4)!)
            buffer.writeBytes(UInt32(f.writerIndex).bytes)
            buffer.writeBytes(f.getBytes(at: 8, length: f.writerIndex - 8)!)
            parts = nil
        }
        
        if let frame = parse(buffer: &buffer) {
            context.fireChannelRead(self.wrapInboundOut(frame))
            return .continue
        }

        return .needMoreData
    }

    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        // EOF is not semantic in WebSocket, so ignore this.
        //return .needMoreData
        try decode(context: context, buffer: &buffer)
    }
    
    public func parse(buffer: inout ByteBuffer) -> OPCUAFrame? {
        guard let messageType = buffer.getString(at: buffer.readerIndex, length: 3),
              let type = MessageTypes(rawValue: messageType) else { return nil }
        
        var head = OPCUAFrameHead()
        head.messageType = type
        head.chunkType = ChunkTypes(rawValue: buffer.getString(at: buffer.readerIndex + 3, length: 1)!)!
        head.messageSize = UInt32(bytes: buffer.getBytes(at: buffer.readerIndex + 4, length: 4)!)
        let messageSize = head.messageSize.int
        let bytes = buffer.getBytes(at: buffer.readerIndex + 8, length: messageSize - 8) ?? [UInt8]()
        
        buffer.moveReaderIndex(forwardBy: messageSize)

        return OPCUAFrame(head: head, body: bytes)
    }
}
