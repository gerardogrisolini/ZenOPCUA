//
//  OPCUAFrameDecoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO

final class OPCUAFrameDecoder: ByteToMessageDecoder {
    public typealias InboundOut = OPCUAFrame
    private var parts: ByteBuffer? = nil
    let byteBufferAllocator = ByteBufferAllocator()

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState  {
        guard buffer.readableBytes >= 8 else { return .needMoreData }

        let lenght = UInt32(bytes: buffer.getBytes(at: buffer.readerIndex + 4, length: 4)!).int
        guard buffer.readableBytes >= lenght else { return .needMoreData }
        //print("\(buffer.readableBytes) >= \(lenght)")
        
        if let chunkType = ChunkTypes(rawValue: buffer.getString(at: buffer.readerIndex + 3, length: 1)!), chunkType == .part {
            let count = buffer.readableBytes / lenght

            if parts == nil {
                parts = context.channel.allocator.buffer(capacity: count * lenght)
                parts!.writeBytes(buffer.getBytes(at: 0, length: 24)!)
            }

            for _ in 0..<count {
                let b = buffer.getBytes(at: buffer.readerIndex, length: lenght)!
                parts!.writeBytes(b[24...])
                buffer.moveReaderIndex(forwardBy: lenght)
            }

            if let chunkType = buffer.getString(at: buffer.readerIndex + 3, length: 1) {
                guard ChunkTypes(rawValue: chunkType)! == .frame else { return .needMoreData }
            } else {
                return .needMoreData
            }
        }

        if var f = parts {
            if buffer.readableBytes > 0 {
                f.writeBytes(buffer.getBytes(at: buffer.readerIndex + 24, length: buffer.readableBytes - 24)!)
                buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
            }
            buffer.clear()
            buffer.writeBytes(f.getBytes(at: 0, length: 4)!)
            buffer.writeBytes(UInt32(f.writerIndex).bytes)
            buffer.writeBytes(f.getBytes(at: 8, length: f.writerIndex - 8)!)
            parts = nil
        }
        
        if let frame = try parse(buffer: &buffer) {
            context.fireChannelRead(self.wrapInboundOut(frame))
            return .continue
        }

        return .needMoreData
    }

    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        //return try decode(context: context, buffer: &buffer)
        // EOF is not semantic in WebSocket, so ignore this.
        return .needMoreData
    }
    
    public func parse(buffer: inout ByteBuffer) throws -> OPCUAFrame? {
        guard let messageType = buffer.getString(at: buffer.readerIndex, length: 3),
              let type = MessageTypes(rawValue: messageType) else { return nil }
        
        if isEncryptionEnabled {
            buffer = try decryptChunk(chunkBuffer: &buffer)
        }

        if isSigningEnabled {
            try verifyChunk(chunkBuffer: &buffer)
        }

        var head = OPCUAFrameHead()
        head.messageType = type
        head.chunkType = ChunkTypes(rawValue: buffer.getString(at: buffer.readerIndex + 3, length: 1)!)!
        head.messageSize = UInt32(bytes: buffer.getBytes(at: buffer.readerIndex + 4, length: 4)!)
        let messageSize = head.messageSize.int
        let bytes = buffer.getBytes(at: buffer.readerIndex + 8, length: messageSize - 8) ?? [UInt8]()
        
        buffer.moveReaderIndex(forwardBy: messageSize)

        return OPCUAFrame(head: head, body: bytes)
    }
    
    private func decryptChunk(chunkBuffer: inout ByteBuffer) throws -> ByteBuffer {
        let cipherTextBlockSize = OPCUAHandler.securityPolicy.getAsymmetricCipherTextBlockSize()
        let blockCount = chunkBuffer.readableBytes / cipherTextBlockSize
        let plainTextBufferSize = cipherTextBlockSize * blockCount
        var plainTextBuffer = byteBufferAllocator.buffer(capacity: plainTextBufferSize)

        do {
            chunkBuffer.moveReaderIndex(forwardBy: OPCUAHandler.securityPolicy.getSecurityHeaderSize())
            chunkBuffer.moveWriterIndex(to: chunkBuffer.readerIndex)

            assert (chunkBuffer.readableBytes % cipherTextBlockSize == 0)

            //if (isAsymmetric()) {
                for _ in 0..<blockCount {
                    let dataToDencrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: cipherTextBlockSize)!
                    chunkBuffer.moveReaderIndex(forwardBy: cipherTextBlockSize)
                    let bytes = try OPCUAHandler.securityPolicy.decrypt(data: dataToDencrypt)
                    plainTextBuffer.writeBytes(bytes)
                }
            //} else {
            //    cipher.doFinal(chunkNioBuffer, plainTextNioBuffer);
            //}

            chunkBuffer.writeBuffer(&plainTextBuffer);
            chunkBuffer.moveReaderIndex(to: 0)
            
            return chunkBuffer
        } catch {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADSECURITYCHECKSFAILED, reason: error.localizedDescription)
        }
    }
    
    public func verifyChunk(chunkBuffer: inout ByteBuffer) throws {
        let signatureSize = OPCUAHandler.securityPolicy.getRemoteAsymmetricSignatureSize()
        chunkBuffer.moveReaderIndex(to: chunkBuffer.writerIndex - signatureSize)

        let signatureBytes = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: signatureSize)!
        if !(try OPCUAHandler.securityPolicy.signVerify(signedData: Data(signatureBytes))) {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADUSERSIGNATUREINVALID)
        }
    }

    var isEncryptionEnabled: Bool {
        return OPCUAHandler.securityPolicy.isAsymmetricEncryptionEnabled()
    }
    
    var isSigningEnabled: Bool {
        return OPCUAHandler.securityPolicy.isAsymmetricSigningEnabled()
    }
}
