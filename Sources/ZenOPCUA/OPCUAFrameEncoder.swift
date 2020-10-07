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
        #if DEBUG
        print(" --> \(frame.head)")
        #endif
        
        //for frame in value.split() {
            var byteBuffer = byteBufferAllocator.buffer(capacity: frame.body.count + 8)
            byteBuffer.writeString("\(frame.head.messageType.rawValue)\(frame.head.chunkType.rawValue)")
            byteBuffer.writeBytes(frame.head.messageSize.bytes)
            byteBuffer.writeBytes(frame.body)
            try signAndEncrypt(messageBuffer: &byteBuffer, out: &out)
        //}
    }
    
    func signAndEncrypt(messageBuffer: inout ByteBuffer, out: inout ByteBuffer) throws {
        let isEncryptionEnabled = OPCUAHandler.securityPolicy.isEncryptionEnabled

        let maxChunkSize = OPCUAHandler.bufferSize
        let paddingOverhead = isEncryptionEnabled ? (cipherTextBlockSize > 256 ? 2 : 1) : 0

        let maxCipherTextSize = maxChunkSize - SECURE_MESSAGE_HEADER_SIZE - securityHeaderSize
        let maxCipherTextBlocks = maxCipherTextSize / cipherTextBlockSize
        let maxPlainTextSize = maxCipherTextBlocks * plainTextBlockSize
        let maxBodySize = maxPlainTextSize - SEQUENCE_HEADER_SIZE - paddingOverhead - signatureSize

        assert (maxPlainTextSize + securityHeaderSize + SECURE_MESSAGE_HEADER_SIZE <= maxChunkSize)

        let header = isEncryptionEnabled ? SECURE_MESSAGE_HEADER_SIZE + (messageBuffer.readableBytes > securityHeaderSize ? securityHeaderSize : 0) : 0
        
        while messageBuffer.readableBytes > 0 {
            let bodySize = min(messageBuffer.readableBytes - header - 8, maxBodySize)

            var paddingSize: Int
            if isEncryptionEnabled {
                let plainTextSize = SEQUENCE_HEADER_SIZE + bodySize + paddingOverhead + signatureSize
                let remaining = plainTextSize % plainTextBlockSize
                paddingSize = remaining > 0 ? plainTextBlockSize - remaining : 0
            } else {
                paddingSize = 0
            }

            let plainTextContentSize = SEQUENCE_HEADER_SIZE + bodySize +
                signatureSize + paddingSize + paddingOverhead

            assert (!isEncryptionEnabled || plainTextContentSize % plainTextBlockSize == 0)

            let chunkSize = isEncryptionEnabled
                ? SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize + (plainTextContentSize / plainTextBlockSize) * cipherTextBlockSize
                : SEQUENCE_HEADER_SIZE + bodySize

            assert (chunkSize <= maxChunkSize)

            var chunkBuffer = byteBufferAllocator.buffer(capacity: chunkSize)
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 3)!)
            messageBuffer.moveReaderIndex(forwardBy: 8)
            chunkBuffer.writeString(messageBuffer.readableBytes - header > bodySize ? "C" : "F")
            chunkBuffer.writeBytes(UInt32(chunkSize).bytes)
            // secureChannelId
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 4)!)
            messageBuffer.moveReaderIndex(forwardBy: 4)
            // tokenlId or secureHeader
            var len = 0
            switch chunkBuffer.getString(at: 0, length: 3)! {
            case "OPN":
                len = securityHeaderSize
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len)!)
                chunkBuffer.writeBytes(nextSequenceNumber().bytes)
                len = len + 4
                messageBuffer.moveReaderIndex(forwardBy: len)
                len = header + bodySize - len - 4
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len)!)
            case "MSG":
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 4)!)
                chunkBuffer.writeBytes(nextSequenceNumber().bytes)
                messageBuffer.moveReaderIndex(forwardBy: 8)
                len = header + bodySize - 12
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len)!)
            default:
                len = header + bodySize - 4
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len)!)
            }
            messageBuffer.moveReaderIndex(forwardBy: len)

            /* Padding and Signature */
            if isEncryptionEnabled {
                writePadding(cipherTextBlockSize, paddingSize, &chunkBuffer)
            }

            if OPCUAHandler.securityPolicy.isSigningEnabled {
                let dataToSign = Data(chunkBuffer.getBytes(at: 0, length: chunkBuffer.writerIndex)!)
                let signature = try OPCUAHandler.securityPolicy.sign(data: dataToSign)
                chunkBuffer.writeBytes(signature)
                #if DEBUG
                print("sign: \(dataToSign.count) => \(chunkBuffer.readableBytes)")
                #endif
            }

            /* Encryption */
            if (isEncryptionEnabled) {
                out.writeBytes(chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: header)!)
                chunkBuffer.moveReaderIndex(to: header)
                
                if OPCUAHandler.securityPolicy.isAsymmetric {
                    assert ((chunkBuffer.readableBytes) % plainTextBlockSize == 0)
                    
                    let blockCount = chunkBuffer.readableBytes / plainTextBlockSize
                    var chunkNioBuffer = byteBufferAllocator.buffer(capacity: blockCount * cipherTextBlockSize)

                    for _ in 0..<blockCount {
                        let dataToEncrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: plainTextBlockSize)!
                        let dataEncrypted = try OPCUAHandler.securityPolicy.cryptAsymmetric(data: dataToEncrypt)
                        
                        assert (dataEncrypted.count == cipherTextBlockSize)
                        
                        chunkNioBuffer.writeBytes(dataEncrypted)
                        out.writeBuffer(&chunkNioBuffer)
                        chunkBuffer.moveReaderIndex(forwardBy: plainTextBlockSize)
                    }
                    #if DEBUG
                    print("encrypt: \(chunkBuffer.readerIndex) => \(header + chunkNioBuffer.writerIndex)")
                    #endif
                } else {

                    let dataToEncrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: chunkBuffer.readableBytes)!
                    let dataEncrypted = try OPCUAHandler.securityPolicy.cryptSymmetric(data: dataToEncrypt)

                    assert (dataEncrypted.count == dataToEncrypt.count)

                    out.writeBytes(dataEncrypted)
                    chunkBuffer.moveReaderIndex(forwardBy: chunkBuffer.readableBytes)
                    #if DEBUG
                    print("encrypt: \(chunkBuffer.readerIndex) => \(header + dataEncrypted.count)")
                    #endif
                }

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

    var securityHeaderSize: Int { OPCUAHandler.securityPolicy.securityHeaderSize }

    var cipherTextBlockSize: Int { OPCUAHandler.securityPolicy.asymmetricCipherTextBlockSize }

    var plainTextBlockSize: Int { OPCUAHandler.securityPolicy.asymmetricPlainTextBlockSize }

    var signatureSize: Int { OPCUAHandler.securityPolicy.asymmetricSignatureSize }
    
    private var sequenceNumber = UInt32(1)
    
    public func resetSequenceNumber() {
        sequenceNumber = 1000
    }

    public func nextSequenceNumber() -> UInt32 {
        sequenceNumber += 1
        return sequenceNumber
    }
}
