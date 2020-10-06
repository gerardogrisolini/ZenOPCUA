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
        
        if OPCUAHandler.securityPolicy.isEncryptionEnabled {
            buffer = try decryptChunk(chunkBuffer: &buffer)
        }

        if OPCUAHandler.securityPolicy.isSigningEnabled {
            //try verifyChunk(chunkBuffer: &buffer)
            buffer.moveWriterIndex(to: buffer.writerIndex - OPCUAHandler.securityPolicy.remoteAsymmetricSignatureSize)
        }

        var head = OPCUAFrameHead()
        head.messageType = type
        head.chunkType = ChunkTypes(rawValue: buffer.getString(at: buffer.readerIndex + 3, length: 1)!)!
        head.messageSize = UInt32(buffer.writerIndex)
        let bytes = buffer.getBytes(at: buffer.readerIndex + 8, length: buffer.writerIndex - 8) ?? [UInt8]()
        
        buffer.moveReaderIndex(forwardBy: buffer.writerIndex)

        return OPCUAFrame(head: head, body: bytes)
    }
    
    private func decryptChunk(chunkBuffer: inout ByteBuffer) throws -> ByteBuffer {
        let cipherTextBlockSize = OPCUAHandler.securityPolicy.asymmetricCipherTextBlockSize
        let header = OPCUAHandler.securityPolicy.isEncryptionEnabled
            ? SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize
            : 0
        
        chunkBuffer.moveReaderIndex(forwardBy: header)
        let blockCount = chunkBuffer.readableBytes / cipherTextBlockSize
        let plainTextBufferSize = cipherTextBlockSize * blockCount
        var plainTextBuffer = byteBufferAllocator.buffer(capacity: plainTextBufferSize)

        do {
            if OPCUAHandler.securityPolicy.isAsymmetric {
            
                assert (chunkBuffer.readableBytes % cipherTextBlockSize == 0)

                for _ in 0..<blockCount {
                    let dataToDencrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: cipherTextBlockSize)!
                    chunkBuffer.moveReaderIndex(forwardBy: cipherTextBlockSize)
                    let bytes = try OPCUAHandler.securityPolicy.decryptAsymmetric(data: dataToDencrypt)
                    plainTextBuffer.writeBytes(bytes)
                }

                chunkBuffer.moveReaderIndex(to: 0)
                chunkBuffer.moveWriterIndex(to: header)
                chunkBuffer.writeBuffer(&plainTextBuffer);
            
            } else {
                
                let dataToDencrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: chunkBuffer.readableBytes)!
                let bytes = try OPCUAHandler.securityPolicy.decryptSymmetric(data: dataToDencrypt)
                chunkBuffer.moveReaderIndex(to: 0)
                chunkBuffer.moveWriterIndex(to: header)
                chunkBuffer.writeBytes(bytes);
            }
            print("decrypt: \(chunkBuffer.writerIndex + header) => \(header + plainTextBuffer.writerIndex)")

            return chunkBuffer
        } catch {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADSECURITYCHECKSFAILED, reason: error.localizedDescription)
        }
    }
    
    public func verifyChunk(chunkBuffer: inout ByteBuffer) throws {
        let signatureSize = OPCUAHandler.securityPolicy.remoteAsymmetricSignatureSize
        let len = chunkBuffer.writerIndex - signatureSize
        let data = Data(chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: len)!)
        let signature = Data(chunkBuffer.getBytes(at: chunkBuffer.readerIndex + len, length: signatureSize)!)
        
        if !(OPCUAHandler.securityPolicy.signVerify(signature: signature, data: data)) {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADUSERSIGNATUREINVALID)
        }

        print("verify: \(chunkBuffer.readableBytes) \(signature.count) => \(data.count)")
    }

    var securityHeaderSize: Int {
        return OPCUAHandler.securityPolicy.isAsymmetricEncryptionEnabled
            ? OPCUAHandler.securityPolicy.securityRemoteHeaderSize
            : 0
    }
}
