//
//  OPCUAFrameDecoder.swift
//
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO

final class OPCUAFrameDecoder {
    public typealias InboundOut = OPCUAFrame
    private var parts: ByteBuffer? = nil
    private var pendingBuffer: ByteBuffer? = nil
    let byteBufferAllocator = ByteBufferAllocator()
    let state: OPCUAConnectionState

    init(state: OPCUAConnectionState) {
        self.state = state
    }

    func appendInboundBuffer(_ buffer: inout ByteBuffer) {
        if pendingBuffer == nil {
            pendingBuffer = buffer
        } else {
            pendingBuffer!.writeBuffer(&buffer)
        }
    }

    func decodeNextFrame() throws -> OPCUAFrame? {
        guard var buffer = pendingBuffer else { return nil }
        if let frame = try decode(buffer: &buffer) {
            pendingBuffer = buffer.readableBytes > 0 ? buffer : nil
            return frame
        }
        pendingBuffer = buffer
        return nil
    }

    private func decode(buffer: inout ByteBuffer) throws -> OPCUAFrame? {
        guard buffer.readableBytes >= 8 else {
            return nil
        }

        guard let lengthBytes = buffer.getBytes(at: buffer.readerIndex + 4, length: 4) else {
            return nil
        }
        let lenght = UInt32(bytes: lengthBytes).int
        guard lenght > 0 else { return nil }
        guard buffer.readableBytes >= lenght else {
            return nil
        }
        //print("\(buffer.readableBytes) >= \(lenght)")
        
        if let chunkTypeRaw = buffer.getString(at: buffer.readerIndex + 3, length: 1),
           let chunkType = ChunkTypes(rawValue: chunkTypeRaw),
           chunkType == .part {
            let count = buffer.readableBytes / lenght

            if parts == nil {
                parts = byteBufferAllocator.buffer(capacity: count * lenght)
                guard let headerBytes = buffer.getBytes(at: buffer.readerIndex, length: 24) else {
                    return nil
                }
                parts!.writeBytes(headerBytes)
            }

            for _ in 0..<count {
                guard let b = buffer.getBytes(at: buffer.readerIndex, length: lenght), b.count >= 24 else {
                    return nil
                }
                parts!.writeBytes(Array(b[24...]))
                buffer.moveReaderIndex(forwardBy: lenght)
            }

            if let chunkType = buffer.getString(at: buffer.readerIndex + 3, length: 1) {
                guard let nextType = ChunkTypes(rawValue: chunkType), nextType == .frame else { return nil }
            } else {
                return nil
            }
        }

        if var f = parts {
            if buffer.readableBytes > 24 {
                guard let bodyBytes = buffer.getBytes(at: buffer.readerIndex + 24, length: buffer.readableBytes - 24) else {
                    return nil
                }
                f.writeBytes(bodyBytes)
                buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
            }
            buffer.clear()
            guard let messageTypeAndChunk = f.getBytes(at: 0, length: 4) else {
                return nil
            }
            buffer.writeBytes(messageTypeAndChunk)
            buffer.writeBytes(UInt32(f.writerIndex).bytes)
            // Ensure we don't try to read negative length
            let dataLength = max(0, f.writerIndex - 8)
            if dataLength > 0 {
                guard let dataBytes = f.getBytes(at: 8, length: dataLength) else {
                    return nil
                }
                buffer.writeBytes(dataBytes)
            }
            parts = nil
        }
        
        if let frame = try parse(buffer: &buffer) {
            return frame
        }
        return nil
    }
    
    public func parse(buffer: inout ByteBuffer) throws -> OPCUAFrame? {
        guard let messageType = buffer.getString(at: buffer.readerIndex, length: 3),
              let type = MessageTypes(rawValue: messageType) else { return nil }
        
        // Hello, Acknowledge, and Error messages are NEVER encrypted, regardless of security settings.
        // Interop: allow encrypted traffic in Sign mode when thumbprint is included.
        let signCompatibilityDecrypt = state.useSignThumbprintCompatibilityEncryption

        let shouldDecrypt = (state.securityPolicy.isEncryptionEnabled || signCompatibilityDecrypt)
            && type != .hello
            && type != .acknowledge
            && type != .error
        
        if shouldDecrypt {
            #if DEBUG
            #endif
            buffer = try decryptChunk(chunkBuffer: &buffer)
            #if DEBUG
            #endif
        }

        // Only remove signature if signing is enabled AND we have remote certificate
        // AND it's not a message type that is never signed (HEL, ACK, ERR)
        let shouldRemoveSignature = state.securityPolicy.isSigningEnabled 
            && state.hasRemoteCertificate
            && type != .hello
            && type != .acknowledge
            && type != .error
        
        if shouldRemoveSignature {
            #if DEBUG
            #endif
            //try verifyChunk(chunkBuffer: &buffer)
            // Ensure we don't move writerIndex to a negative value
            if buffer.writerIndex >= signatureSize {
                buffer.moveWriterIndex(to: buffer.writerIndex - signatureSize)
            } else {
            }
        }

        var head = OPCUAFrameHead()
        head.messageType = type
        guard let chunkTypeRaw = buffer.getString(at: buffer.readerIndex + 3, length: 1),
              let chunkType = ChunkTypes(rawValue: chunkTypeRaw) else {
            return nil
        }
        head.chunkType = chunkType
        
        head.messageSize = UInt32(buffer.writerIndex)
        
        // Ensure we don't try to read negative length
        let bodyLength = max(0, buffer.writerIndex - 8)
        
        let bytes = bodyLength > 0 
            ? (buffer.getBytes(at: buffer.readerIndex + 8, length: bodyLength) ?? [UInt8]())
            : [UInt8]()
        buffer.moveReaderIndex(forwardBy: buffer.writerIndex)

        return OPCUAFrame(head: head, body: bytes)
    }
    
    private func decryptChunk(chunkBuffer: inout ByteBuffer) throws -> ByteBuffer {
        let messageType = chunkBuffer.getString(at: chunkBuffer.readerIndex, length: 3) ?? ""
        let isSignCompatibilityEncrypted = state.useSignThumbprintCompatibilityEncryption

        let isEncryptionEnabled = state.securityPolicy.isEncryptionEnabled || isSignCompatibilityEncrypted
        let isAsymmetric = state.securityPolicy.isAsymmetric

        let cipherTextBlockSize = isAsymmetric 
            ? state.securityPolicy.asymmetricCipherTextBlockSize
            : state.securityPolicy.symmetricBlockSize
        // For symmetric MSG/CLO, header includes: messageType(3) + chunkType(1) + size(4) + channelId(4) + tokenId(4) = 16
        // For asymmetric OPN, header includes: messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader
        let header = isEncryptionEnabled
            ? isAsymmetric
                ? SECURE_MESSAGE_HEADER_SIZE + (
                    messageType == "OPN"
                        ? calculateSecurityHeaderSizeFromBuffer(chunkBuffer)
                        : securityHeaderSize
                )
                : SECURE_MESSAGE_HEADER_SIZE + 4  // Add 4 for tokenId in MSG/CLO
            : 0

        guard chunkBuffer.readableBytes >= header else {
            throw OPCUAError.generic("Encrypted chunk too small for header: readable=\(chunkBuffer.readableBytes), header=\(header), type=\(messageType)")
        }
        chunkBuffer.moveReaderIndex(forwardBy: header)
        let blockCount = chunkBuffer.readableBytes / cipherTextBlockSize
        let plainTextBufferSize = cipherTextBlockSize * blockCount
        guard plainTextBufferSize >= 0 && plainTextBufferSize <= Int.max else {
            throw OPCUAError.generic("Invalid plainTextBufferSize: \(plainTextBufferSize)")
        }
        var plainTextBuffer = byteBufferAllocator.buffer(capacity: plainTextBufferSize)

        do {
            if state.securityPolicy.isAsymmetric {
                if chunkBuffer.readableBytes % cipherTextBlockSize != 0 {
                    throw OPCUAError.generic(
                        "Asymmetric decrypt alignment error: readable=\(chunkBuffer.readableBytes), block=\(cipherTextBlockSize), header=\(header), type=\(messageType)"
                    )
                }

                for _ in 0..<blockCount {
                    guard let dataToDencrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: cipherTextBlockSize) else {
                        throw OPCUAError.generic("Cannot read asymmetric encrypted block")
                    }
                    chunkBuffer.moveReaderIndex(forwardBy: cipherTextBlockSize)
                    let bytes = try state.securityPolicy.decryptAsymmetric(data: dataToDencrypt)
                    plainTextBuffer.writeBytes(bytes)
                }

                chunkBuffer.moveReaderIndex(to: 0)
                chunkBuffer.moveWriterIndex(to: header)
                chunkBuffer.writeBuffer(&plainTextBuffer);
            
            } else {
                
                guard let dataToDencrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: chunkBuffer.readableBytes) else {
                    throw OPCUAError.generic("Cannot read symmetric encrypted block")
                }
                let bytes = try state.securityPolicy.decryptSymmetric(data: dataToDencrypt)
                chunkBuffer.moveReaderIndex(to: 0)
                chunkBuffer.moveWriterIndex(to: header)
                chunkBuffer.writeBytes(bytes);
            }
            return chunkBuffer
        } catch {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADSECURITYCHECKSFAILED, reason: error.localizedDescription)
        }
    }

    private func calculateSecurityHeaderSizeFromBuffer(_ buffer: ByteBuffer) -> Int {
        var offset = buffer.readerIndex + 12 // MessageHeader + SecureChannelId
        var total = 0

        func readLength() -> UInt32? {
            guard let value = buffer.getInteger(at: offset, endianness: .little, as: UInt32.self) else {
                return nil
            }
            offset += 4
            total += 4
            return value
        }

        guard let policyLen = readLength() else { return 0 }
        guard policyLen == UInt32.max || offset + Int(policyLen) <= buffer.readerIndex + buffer.readableBytes else { return 0 }
        if policyLen != UInt32.max {
            offset += Int(policyLen)
            total += Int(policyLen)
        }

        guard let senderCertLen = readLength() else { return 0 }
        guard senderCertLen == UInt32.max || offset + Int(senderCertLen) <= buffer.readerIndex + buffer.readableBytes else { return 0 }
        if senderCertLen != UInt32.max {
            offset += Int(senderCertLen)
            total += Int(senderCertLen)
        }

        guard let thumbLen = readLength() else { return 0 }
        guard thumbLen == UInt32.max || offset + Int(thumbLen) <= buffer.readerIndex + buffer.readableBytes else { return 0 }
        if thumbLen != UInt32.max {
            total += Int(thumbLen)
        }

        return total
    }
    
    public func verifyChunk(chunkBuffer: inout ByteBuffer) throws {
        let signatureSize = state.securityPolicy.remoteAsymmetricSignatureSize
        
        // Ensure we have enough data for signature verification
        guard chunkBuffer.writerIndex >= signatureSize else {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADSECURITYCHECKSFAILED, 
                                 reason: "Buffer too small for signature: writerIndex=\(chunkBuffer.writerIndex), signatureSize=\(signatureSize)")
        }
        
        let len = chunkBuffer.writerIndex - signatureSize
        guard let dataBytes = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: len),
              let signatureBytes = chunkBuffer.getBytes(at: chunkBuffer.readerIndex + len, length: signatureSize) else {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADSECURITYCHECKSFAILED, reason: "Cannot read signature payload")
        }
        let data = Data(dataBytes)
        let signature = Data(signatureBytes)
        
        if !(state.securityPolicy.signVerify(signature: signature, data: data)) {
            throw OPCUAError.code(StatusCodes.UA_STATUSCODE_BADUSERSIGNATUREINVALID)
        }
        
    }

    var securityHeaderSize: Int {
        return state.securityPolicy.isAsymmetric
            ? state.securityPolicy.securityRemoteHeaderSize
            : 0
    }
    
    var signatureSize: Int {
        return state.securityPolicy.isAsymmetric
            ? state.securityPolicy.remoteAsymmetricSignatureSize
            : state.securityPolicy.symmetricSignatureSize
    }
}
