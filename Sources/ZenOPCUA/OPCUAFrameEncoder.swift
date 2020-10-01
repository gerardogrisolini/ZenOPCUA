//
//  OPCUAFrameEncoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import NIO

let SEQUENCE_HEADER_SIZE: Int = 8
let SECURE_MESSAGE_HEADER_SIZE: Int = 12

public final class OPCUAFrameEncoder: MessageToByteEncoder {
    public typealias OutboundIn = OPCUAFrame

    let byteBufferAllocator = ByteBufferAllocator()
    
    public func encode(data frame: OPCUAFrame, out: inout ByteBuffer) throws {
        //for frame in value.split() {
            var byteBuffer = byteBufferAllocator.buffer(capacity: frame.body.count + 8)
            byteBuffer.writeString("\(frame.head.messageType.rawValue)\(frame.head.chunkType.rawValue)")
            byteBuffer.writeBytes(frame.head.messageSize.bytes)
            byteBuffer.writeBytes(frame.body)
            try signAndEncrypt(messageBuffer: &byteBuffer, out: &out)
        //}
    }
    
    func signAndEncrypt(messageBuffer: inout ByteBuffer, out: inout ByteBuffer) throws {
        let encrypted = isAsymmetricEncryptionEnabled
        
        let maxChunkSize = OPCUAHandler.bufferSize
        let paddingOverhead = encrypted ? (cipherTextBlockSize > 256 ? 2 : 1) : 0

        let maxCipherTextSize = maxChunkSize - SECURE_MESSAGE_HEADER_SIZE - securityHeaderSize
        let maxCipherTextBlocks = maxCipherTextSize / cipherTextBlockSize
        let maxPlainTextSize = maxCipherTextBlocks * plainTextBlockSize
        let maxBodySize = maxPlainTextSize - SEQUENCE_HEADER_SIZE - paddingOverhead - signatureSize

        assert (maxPlainTextSize + securityHeaderSize + SECURE_MESSAGE_HEADER_SIZE <= maxChunkSize)

        let header = encrypted ? SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize : 0
        while messageBuffer.readableBytes > 0 {
            let bodySize = min(messageBuffer.readableBytes - header - 8, maxBodySize)

            var paddingSize: Int
            if encrypted {
                let plainTextSize = SEQUENCE_HEADER_SIZE + bodySize + paddingOverhead + signatureSize
                let remaining = plainTextSize % plainTextBlockSize
                paddingSize = remaining > 0 ? plainTextBlockSize - remaining : 0
            } else {
                paddingSize = 0
            }

            let plainTextContentSize = SEQUENCE_HEADER_SIZE + bodySize +
                signatureSize + paddingSize + paddingOverhead

            assert (!encrypted || plainTextContentSize % plainTextBlockSize == 0)

            let chunkSize = encrypted
                ? SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize +
                (plainTextContentSize / plainTextBlockSize) * cipherTextBlockSize
                : SEQUENCE_HEADER_SIZE + bodySize

            assert (chunkSize <= maxChunkSize)

            var chunkBuffer = byteBufferAllocator.buffer(capacity: chunkSize)
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 3)!)
            messageBuffer.moveReaderIndex(forwardBy: 8)
            
            let chunkType = messageBuffer.readableBytes - header > bodySize ? "C" : "F"
            print("\(messageBuffer.readableBytes - header) > \(bodySize) = \(chunkType) (\(header))")
            
            chunkBuffer.writeString(chunkType)
            chunkBuffer.writeBytes(UInt32(chunkSize).bytes)
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: header + bodySize)!)
            messageBuffer.moveReaderIndex(forwardBy: header + bodySize)

            /* Padding and Signature */
            if encrypted {
                writePadding(cipherTextBlockSize, paddingSize, &chunkBuffer)
            }

            if isAsymmetricSigningEnabled {
                let dataToSign = Data(chunkBuffer.getBytes(at: 0, length: chunkBuffer.readableBytes)!)
                let signature = try OPCUAHandler.securityPolicy.sign(dataToSign: dataToSign)
                chunkBuffer.writeBytes(signature)
                print("sign: \(dataToSign.count) signature: \(signature.count) => chunkBuffer: \(chunkBuffer.readableBytes)")
            }

            /* Encryption */
            if (encrypted) {
                out.writeBytes(chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: header)!)
                chunkBuffer.moveReaderIndex(to: header)
                
                assert ((chunkBuffer.readableBytes) % plainTextBlockSize == 0)
                
                let blockCount = chunkBuffer.readableBytes / plainTextBlockSize
                var chunkNioBuffer = byteBufferAllocator.buffer(capacity: blockCount * cipherTextBlockSize)

                for _ in 0..<blockCount {
                    let dataToEncrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: plainTextBlockSize)!
                    let dataEncrypted = try OPCUAHandler.securityPolicy.crypt(dataToEncrypt: dataToEncrypt)
                    
                    assert (dataEncrypted.count == cipherTextBlockSize)
                    
                    chunkNioBuffer.writeBytes(dataEncrypted)
                    chunkBuffer.moveReaderIndex(forwardBy: plainTextBlockSize)
                }
                print("encrypt: chunkBuffer => \(chunkBuffer.readerIndex) => chunkNioBuffer: \(header + chunkNioBuffer.readableBytes)")

                out.writeBuffer(&chunkNioBuffer)
            } else {
                out.writeBuffer(&chunkBuffer)
            }
        }
    }
    
    func writePadding(_ cipherTextBlockSize: Int, _ paddingSize: Int, _ buffer: inout ByteBuffer) {
        if cipherTextBlockSize > 256 {
            buffer.writeInteger(paddingSize)
        } else {
            buffer.writeBytes([UInt8(paddingSize)])
        }

        buffer.writeBytes([UInt8](repeating: UInt8(paddingSize), count: paddingSize))

        if cipherTextBlockSize > 256 {
            // Replace the last byte with the MSB of the 2-byte padding length
            let paddingLengthMsb: Int = paddingSize >> 8
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
            buffer.writeBytes(paddingLengthMsb.bytes)
        }
    }

    var securityHeaderSize: Int {
        return OPCUAHandler.securityPolicy.getSecurityHeaderSize()
    }

    var cipherTextBlockSize: Int {
        return OPCUAHandler.securityPolicy.getAsymmetricCipherTextBlockSize()
    }

    var plainTextBlockSize: Int {
        return OPCUAHandler.securityPolicy.getAsymmetricPlainTextBlockSize()
    }

    var signatureSize: Int {
        return OPCUAHandler.securityPolicy.getAsymmetricSignatureSize()
    }
    
    var isAsymmetricSigningEnabled: Bool {
        return OPCUAHandler.securityPolicy.isAsymmetricSigningEnabled()
    }

    var isAsymmetricEncryptionEnabled: Bool {
        return OPCUAHandler.securityPolicy.isAsymmetricEncryptionEnabled()
    }
}
