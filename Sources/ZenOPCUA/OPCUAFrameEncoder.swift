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
//        #if DEBUG
//        print(" --> \(frame.head)")
//        #endif
        
        var messageBuffer = frame.buffer
        let isEncryptionEnabled = OPCUAHandler.securityPolicy.isEncryptionEnabled
        let isSignedEnabled = OPCUAHandler.securityPolicy.isSigningEnabled
        let isAsymmetric = OPCUAHandler.securityPolicy.isAsymmetric
        
        let maxChunkSize = OPCUAHandler.bufferSize
        let paddingOverhead = isEncryptionEnabled ? (cipherTextBlockSize > 256 ? 2 : 1) : 0

        let maxCipherTextSize = maxChunkSize - SECURE_MESSAGE_HEADER_SIZE - securityHeaderSize
        let maxCipherTextBlocks = maxCipherTextSize / cipherTextBlockSize
        let maxPlainTextSize = maxCipherTextBlocks * plainTextBlockSize
        let maxBodySize = maxPlainTextSize - SEQUENCE_HEADER_SIZE - paddingOverhead - signatureSize

        assert (maxPlainTextSize + securityHeaderSize + SECURE_MESSAGE_HEADER_SIZE <= maxChunkSize)
        
        let header = isEncryptionEnabled
            ? isAsymmetric
                ? SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize
                : SECURE_MESSAGE_HEADER_SIZE
            : 0
        
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
                ? isAsymmetric
                    ? SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize + (plainTextContentSize / plainTextBlockSize) * cipherTextBlockSize
                    : SECURE_MESSAGE_HEADER_SIZE + plainTextContentSize
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
            case "MSG", "CLO":
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
                #if DEBUG
                print("padding: \(chunkSize) => \(chunkBuffer.readableBytes)")
                #endif
            }

            if isSignedEnabled {
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
                
                if isAsymmetric {
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

    var signatureSize: Int {
        OPCUAHandler.securityPolicy.isAsymmetric
        ? OPCUAHandler.securityPolicy.asymmetricSignatureSize
        : OPCUAHandler.securityPolicy.symmetricSignatureSize
    }
    
    private static var sequenceNumber = UInt32(1)
    
    public static func resetSequenceNumber() {
        OPCUAFrameEncoder.sequenceNumber = 1
    }

    public func nextSequenceNumber() -> UInt32 {
        OPCUAFrameEncoder.sequenceNumber += 1
        return OPCUAFrameEncoder.sequenceNumber
    }
}
