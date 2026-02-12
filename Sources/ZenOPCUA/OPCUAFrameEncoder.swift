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

final class OPCUAFrameEncoder {
    let byteBufferAllocator = ByteBufferAllocator()
    let state: OPCUAConnectionState
    
    init(state: OPCUAConnectionState) {
        self.state = state
    }
    
    func encode(frame: OPCUAFrame, out: inout ByteBuffer) throws {
        // Hello and Acknowledge messages are never secured, regardless of security policy
        // They are written directly without chunking or security processing
        if frame.head.messageType == .hello || frame.head.messageType == .acknowledge {
            var buffer = frame.buffer
            out.writeBuffer(&buffer)
            return
        }
        
        var messageBuffer = frame.buffer
        // CRITICAL: We cannot access SecurityPolicy properties that check certificate arrays
        // during encoding because it causes "Negative value is not representable" crash.
        // Instead, we use the isFirstConnection flag to determine security state.
        
        var isEncryptionEnabled: Bool
        let isSigningEnabled: Bool
        let isAsymmetric: Bool
        let calculatedSignatureSize: Int
        
        if state.isFirstConnection {
            // First connection - no security (we don't have remote certificate yet)
            isEncryptionEnabled = false
            isSigningEnabled = false
            isAsymmetric = true  // First OpenSecureChannel is always asymmetric
            calculatedSignatureSize = 0
        } else {
            // Subsequent connections - determine based on message security mode
            let secMode = state.messageSecurityMode
            isSigningEnabled = secMode != .none
            
            // Check if we have symmetric keys (means we're past first OpenSecureChannel)
            isAsymmetric = !state.hasSymmetricKeys
            
            // For MSG/CLO messages, we can only encrypt if we have symmetric keys
            // Even if messageSecurityMode is .signAndEncrypt, we can't encrypt without keys
            if frame.head.messageType == .openChannel {
                // OpenSecureChannelRequest uses asymmetric security.
                // Encrypt OPN when SignAndEncrypt is requested and the server cert is known.
                isEncryptionEnabled = secMode == .signAndEncrypt && state.hasRemoteCertificate
            } else {
                // MSG/CLO messages require symmetric keys for encryption
                isEncryptionEnabled = secMode == .signAndEncrypt && state.hasSymmetricKeys
            }
            
            if isAsymmetric {
                calculatedSignatureSize = state.securityPolicy.asymmetricSignatureSize
            } else {
                calculatedSignatureSize = state.securityPolicy.symmetricSignatureSize
            }
        }
        
        let maxChunkSize = state.bufferSize
        let paddingOverhead = isEncryptionEnabled ? (cipherTextBlockSize > 256 ? 2 : 1) : 0

        // Calculate maximum body size based on whether encryption is enabled
        let maxBodySize: Int
        if isEncryptionEnabled {
            // With encryption, we need to account for block sizes
            let maxCipherTextSize = maxChunkSize - SECURE_MESSAGE_HEADER_SIZE - securityHeaderSize
            let maxCipherTextBlocks = maxCipherTextSize / cipherTextBlockSize
            let maxPlainTextSize = maxCipherTextBlocks * plainTextBlockSize
            maxBodySize = max(0, maxPlainTextSize - SEQUENCE_HEADER_SIZE - paddingOverhead - calculatedSignatureSize)
            
            assert (maxPlainTextSize + securityHeaderSize + SECURE_MESSAGE_HEADER_SIZE <= maxChunkSize)
        } else {
            // Without encryption, calculate based on the actual message structure
            // For asymmetric (OPN): messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader + seqNum(4) + reqId(4) + body + signature
            // For symmetric (MSG/CLO): messageType(3) + chunkType(1) + size(4) + channelId(4) + tokenId(4) + seqNum(4) + reqId(4) + body
            if isAsymmetric {
                let overhead = 3 + 1 + 4 + 4 + securityHeaderSize + 4 + 4 + calculatedSignatureSize
                maxBodySize = max(0, maxChunkSize - overhead)
            } else {
                maxBodySize = maxChunkSize - (3 + 1 + 4 + 4 + 4 + 4 + 4)
            }
        }

        // Calculate header size to determine where the body starts in the original buffer
        // The messageBuffer includes everything from messageType onward
        // For OPN messages: messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader + seqNum(4) + reqId(4) + body
        // For MSG/CLO messages: messageType(3) + chunkType(1) + size(4) + channelId(4) + tokenId(4) + seqNum(4) + reqId(4) + body
        // We need to account for what's BEFORE the body data
        // When calculating bodySize, we subtract (header + 8) because:
        // - 8 bytes are the initial messageType(3) + chunkType(1) + size(4) that we skip
        // - header is everything else before the body starts
        // Determine header size based on the actual message type, not isAsymmetric
        let messageTypeStr = messageBuffer.getString(at: 0, length: 3) ?? ""
        let header: Int
        let actualSecurityHeaderSize: Int
        
        if messageTypeStr == "OPN" {
            // OPN message: channelId(4) + securityHeader(policyUri + cert + thumb) + seqNum(4)
            // The sequenceNumber is skipped in the encoder (line ~178), so we include it in header calculation
            // to exclude it from bodySize
            // Calculate actual security header size from the buffer to avoid accessing SecurityPolicy properties
            let calculatedSize = calculateSecurityHeaderSizeFromBuffer(messageBuffer)
            if calculatedSize > 0 {
                actualSecurityHeaderSize = calculatedSize
                header = 4 + actualSecurityHeaderSize + 4
            } else {
                // Failed to read security header, use fallback based on first connection flag
                let fallbackSize = state.isFirstConnection ? 59 : 1115
                actualSecurityHeaderSize = fallbackSize
                header = 4 + fallbackSize + 4
            }

        } else {
            actualSecurityHeaderSize = 0
            // MSG/CLO message: channelId(4) + tokenId(4) + seqNum(4) + reqId(4)
            header = 16
        }
        
        while messageBuffer.readableBytes > 0 {
            // messageBuffer structure: messageType(3) + chunkType(1) + size(4) + channelId + [rest of header] + body
            // The 'header' variable represents everything between the first 8 bytes and the body
            // So total header size = 8 + header
            // We need at least the header to process a message (body can be 0)
            let totalHeaderSize = 8 + header
            
            // Calculate available bytes for body
            // If readableBytes < totalHeaderSize, we don't have a complete message
            // If readableBytes == totalHeaderSize, we have a message with no body (bodySize = 0)
            // If readableBytes > totalHeaderSize, we have a message with a body
            guard messageBuffer.readableBytes >= totalHeaderSize else {
                break
            }
            
            let availableForBody = messageBuffer.readableBytes - totalHeaderSize
            // Ensure maxBodySize is not negative (which can happen with large security headers)
            let effectiveMaxBodySize = max(1, maxBodySize)
            let bodySize = min(availableForBody, effectiveMaxBodySize)
            
            var paddingSize: Int
            if isEncryptionEnabled {
                // Calculate padding for: sequenceHeader + body + signature
                // According to OPC UA Part 6, Section 6.7.3.2:
                // For OPN: sequenceHeaderSize is SequenceNumber(4), bodySize includes RequestId(4) + body
                //          So total plaintext = seqNum(4) + reqId(4) + body = 4 + bodySize
                // For MSG/CLO: sequenceHeaderSize is SequenceNumber(4) + RequestId(4) = 8, bodySize is just body
                //          So total plaintext = seqNum(4) + reqId(4) + body = 8 + bodySize
                let sequenceHeaderSize = (messageTypeStr == "OPN") ? 4 : SEQUENCE_HEADER_SIZE
                let plainTextSize = sequenceHeaderSize + bodySize + calculatedSignatureSize
                // OPC UA Part 6: PaddingSize is the number of padding bytes (not including the PaddingSize field).
                // For keys <= 2048, paddingOverhead is 1 (PaddingSize byte). For >2048, it is 2.
                let remainder = (plainTextSize + paddingOverhead) % plainTextBlockSize
                let paddingBytes = remainder == 0 ? plainTextBlockSize : (plainTextBlockSize - remainder)
                paddingSize = paddingBytes
                
            } else {
                paddingSize = 0
            }

            // For encrypted messages, plainTextContentSize is the total plaintext to encrypt
            // For OPN: seqNum(4) + bodySize (which includes reqId+body) + signature + padding
            // For MSG/CLO: seqNum(4) + reqId(4) + bodySize (just body) + signature + padding  
            let sequenceHeaderSizeForContent = (messageTypeStr == "OPN") ? 4 : SEQUENCE_HEADER_SIZE
            let paddingFieldSize = paddingSize + paddingOverhead
            let plainTextContentSize = sequenceHeaderSizeForContent + bodySize +
                calculatedSignatureSize + paddingFieldSize
            

            // assert (!isEncryptionEnabled || plainTextContentSize % plainTextBlockSize == 0)

            let chunkSize: Int
            if isEncryptionEnabled {
                if messageTypeStr == "OPN" {
                    chunkSize = SECURE_MESSAGE_HEADER_SIZE + actualSecurityHeaderSize + (plainTextContentSize / plainTextBlockSize) * cipherTextBlockSize
                } else {
                    // MSG/CLO: messageType(3) + chunkType(1) + size(4) + channelId(4) + tokenId(4) + encrypted content
                    chunkSize = SECURE_MESSAGE_HEADER_SIZE + 4 + plainTextContentSize
                }
            } else if calculatedSignatureSize > 0 && messageTypeStr == "OPN" {
                // OPN with signing only (no encryption): messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader + seqNum(4) + (requestId+body) + signature
                // bodySize already includes requestId
                chunkSize = 3 + 1 + 4 + 4 + actualSecurityHeaderSize + 4 + bodySize + calculatedSignatureSize
            } else if messageTypeStr == "OPN" {
                // OPN without security: messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader + seqNum(4) + (requestId+body)
                // bodySize already includes requestId since we calculated it after including seqNum in header
                chunkSize = 3 + 1 + 4 + 4 + actualSecurityHeaderSize + 4 + bodySize
            } else {
                // MSG/CLO without security: messageType(3) + chunkType(1) + size(4) + channelId(4) + tokenId(4) + seqNum(4) + requestId(4) + body
                chunkSize = 3 + 1 + 4 + 4 + 4 + 4 + 4 + bodySize
            }

            // Determine if this is the final chunk or if there will be more
            // We check BEFORE moving the readerIndex
            let isFinalChunk = (messageBuffer.readableBytes - totalHeaderSize) <= bodySize
            let chunkType = isFinalChunk ? "F" : "C"

            guard chunkSize > 0 && chunkSize <= maxChunkSize else {
                throw OPCUAError.generic("Invalid chunk size: \(chunkSize)")
            }
            var chunkBuffer = byteBufferAllocator.buffer(capacity: chunkSize)
            
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 3)!)
            messageBuffer.moveReaderIndex(forwardBy: 8)
            chunkBuffer.writeString(chunkType)
            chunkBuffer.writeBytes(UInt32(chunkSize).bytes)
            // secureChannelId
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 4)!)
            messageBuffer.moveReaderIndex(forwardBy: 4)
            // tokenlId or secureHeader
            var len = 0
            switch chunkBuffer.getString(at: 0, length: 3)! {
            case "OPN":
                // Read security header (policyUri + certificate + thumbprint)
                // Use actualSecurityHeaderSize which was calculated from the buffer
                len = actualSecurityHeaderSize
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len)!)
                // Write new sequence number (replaces the one in original buffer)
                chunkBuffer.writeBytes(state.nextSequenceNumber().bytes)
                // Skip security header + original sequence number in source buffer
                messageBuffer.moveReaderIndex(forwardBy: len + 4)
                // Read requestId + body content
                // For OPN, the SequenceHeader is ONLY SequenceNumber (4 bytes)
                // The RequestId is part of the encrypted body, NOT part of the sequence header
                // bodySize already includes requestId since header calculation includes seqNum
                len = bodySize
                guard let bytes = messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len) else {
                    print("ERROR in OPN case: Cannot read \(len) bytes from messageBuffer")
                    print("  messageBuffer.readerIndex=\(messageBuffer.readerIndex), readableBytes=\(messageBuffer.readableBytes)")
                    print("  bodySize=\(bodySize), securityHeaderSize=\(securityHeaderSize)")
                    throw OPCUAError.generic("Cannot read \(len) bytes from buffer in OPN case")
                }
                chunkBuffer.writeBytes(bytes)
            case "MSG", "CLO":
                // Read tokenId (4 bytes)
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: 4)!)
                // Write new sequence number
                chunkBuffer.writeBytes(state.nextSequenceNumber().bytes)
                // Skip tokenId(4) + original seqNum(4) in source buffer
                messageBuffer.moveReaderIndex(forwardBy: 8)
                // Read reqId(4) + body
                // For MSG/CLO, header=16 includes channelId(4)+tokenId(4)+seqNum(4)+reqId(4)
                // We've already consumed channelId(4) and now tokenId(4)+seqNum(4)=8
                // So we need to read reqId(4) + body = header - 12 + bodySize
                len = header - 12 + bodySize
                chunkBuffer.writeBytes(messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len)!)
            default:
                len = header + bodySize - 4
                guard let bytes = messageBuffer.getBytes(at: messageBuffer.readerIndex, length: len) else {
                    print("ERROR in default case: Cannot read \(len) bytes from messageBuffer")
                    print("  messageBuffer.readerIndex=\(messageBuffer.readerIndex), readableBytes=\(messageBuffer.readableBytes)")
                    print("  header=\(header), bodySize=\(bodySize)")
                    throw OPCUAError.generic("Cannot read \(len) bytes from buffer")
                }
                chunkBuffer.writeBytes(bytes)
            }
            messageBuffer.moveReaderIndex(forwardBy: len)

            /* Padding and Signature */
            // Add padding before signing for encrypted messages.
            if isEncryptionEnabled {
                writePadding(cipherTextBlockSize, paddingSize, &chunkBuffer)
            }

            // Only add signature if we have remote certificate (calculatedSignatureSize > 0)
            if isSigningEnabled && calculatedSignatureSize > 0 {
                // According to OPC UA Part 6, Section 6.7.3.2:
                // For encrypted messages, sign only the plaintext that will be encrypted.
                // For unencrypted messages, sign everything except MessageType, ChunkType, and MessageSize.
                let signStartPos: Int
                if isEncryptionEnabled {
                    if messageTypeStr == "OPN",
                       state.securityPolicy.securityPolicyUri.securityPolicy == .aes256Sha256RsaPss {
                        // For Aes256_Sha256_RsaPss, sign the plaintext section (sequence header + body + padding).
                        signStartPos = 8 + 4 + actualSecurityHeaderSize
                    } else {
                        // For unauthenticated encryption (Basic256Sha256), signature includes headers + message data + padding.
                        signStartPos = 0
                    }
                } else {
                    signStartPos = 8
                }
                let dataToSign = Data(chunkBuffer.getBytes(at: signStartPos, length: chunkBuffer.writerIndex - signStartPos)!)
                let signature = try state.securityPolicy.sign(data: dataToSign)
                chunkBuffer.writeBytes(signature)

                #if false
                let localVerify: Bool
                if isAsymmetric {
                    localVerify = state.securityPolicy.signVerify(signature: signature, data: dataToSign)
                } else {
                    localVerify = state.securityPolicy.signVerifySymmetricLocal(signature: signature, data: dataToSign)
                }
                #endif
            }


            /* Encryption */
            if (isEncryptionEnabled) {
                // For OPN messages, the unencrypted part includes:
                // messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader
                // The 'header' variable doesn't include the first 8 bytes (messageType+chunkType+size)
                // so we need to add them when determining what to skip before encryption
                let unencryptedPartSize: Int
                if messageTypeStr == "OPN" {
                    unencryptedPartSize = 8 + 4 + actualSecurityHeaderSize  // msg(3) + chunk(1) + size(4) + channelId(4) + secHeader
                } else {
                    unencryptedPartSize = 16  // For MSG/CLO: msg(3) + chunk(1) + size(4) + channelId(4) + tokenId(4)
                }
                
                out.writeBytes(chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: unencryptedPartSize)!)
                chunkBuffer.moveReaderIndex(to: unencryptedPartSize)
                
                if isAsymmetric {
                    // Temporarily comment out assertion to see actual values
                    // assert ((chunkBuffer.readableBytes) % plainTextBlockSize == 0)
                    if (chunkBuffer.readableBytes % plainTextBlockSize != 0) {
                        print("ERROR: chunkBuffer.readableBytes (\(chunkBuffer.readableBytes)) is not divisible by plainTextBlockSize (\(plainTextBlockSize))")
                        print("  Difference: \(chunkBuffer.readableBytes % plainTextBlockSize)")
                        throw OPCUAError.generic("Encryption alignment error")
                    }
                    
                    let blockCount = chunkBuffer.readableBytes / plainTextBlockSize
                    var chunkNioBuffer = byteBufferAllocator.buffer(capacity: blockCount * cipherTextBlockSize)

                    for _ in 0..<blockCount {
                        let dataToEncrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: plainTextBlockSize)!
                        
                        let dataEncrypted: [UInt8]
                        dataEncrypted = try state.securityPolicy.cryptAsymmetric(data: dataToEncrypt)
                        
                        assert (dataEncrypted.count == cipherTextBlockSize)
                                                
                        chunkNioBuffer.writeBytes(dataEncrypted)
                        out.writeBuffer(&chunkNioBuffer)
                        chunkBuffer.moveReaderIndex(forwardBy: plainTextBlockSize)
                    }
                    

                } else {

                    let dataToEncrypt = chunkBuffer.getBytes(at: chunkBuffer.readerIndex, length: chunkBuffer.readableBytes)!
                    let dataEncrypted = try state.securityPolicy.cryptSymmetric(data: dataToEncrypt)

                    assert (dataEncrypted.count == dataToEncrypt.count)

                    out.writeBytes(dataEncrypted)
                    chunkBuffer.moveReaderIndex(forwardBy: chunkBuffer.readableBytes)
                }

            } else {
                out.writeBuffer(&chunkBuffer)
            }
        }
    }
    
    func writePadding(_ cipherTextBlockSize: Int, _ paddingSize: Int, _ buffer: inout ByteBuffer) {
        // According to OPC UA Part 6, Section 6.7.3.2:
        // PaddingSize value equals the number of padding bytes.
        // Each padding byte has value = PaddingSize.
        // The PaddingSize field is written LAST (after padding bytes).
        //
        // If paddingSize (the variable) = number of padding bytes to add:
        // - Write paddingSize bytes, each with value = paddingSize
        // - Write 1 PaddingSize byte with value = paddingSize
        
        let paddingSizeValue = UInt8(clamping: paddingSize)
        
        // Write Padding bytes (if any)
        if paddingSize > 0 {
            buffer.writeBytes([UInt8](repeating: paddingSizeValue, count: paddingSize))
        }
        
        // Write the PaddingSize byte last (even if zero)
        if cipherTextBlockSize > 256 {
            // For RSA key sizes > 2048, use UInt16 for padding size (LSB first)
            buffer.writeInteger(UInt16(paddingSizeValue))
        } else {
            // For RSA 2048 or less, use single byte
            buffer.writeBytes([paddingSizeValue])
        }
        
    }

    // Calculate security header size by reading from the buffer
    func calculateSecurityHeaderSizeFromBuffer(_ buffer: ByteBuffer) -> Int {
        // Buffer structure: messageType(3) + chunkType(1) + size(4) + channelId(4) + securityHeader
        // securityHeader = securityPolicyUri + senderCertificate + receiverCertificateThumbprint
        // Each field is: UInt32(length) + data (or 0xFFFFFFFF for placeholder)
        
        // Start reading from current readerIndex + 12 bytes (skip header)
        let startOffset = buffer.readerIndex + 12
        var offset = startOffset
        var totalSize = 0
        
        // Read policyUri length
        guard let policyUriLength = buffer.getInteger(at: offset, endianness: .little, as: UInt32.self) else {
            return 0
        }

        totalSize += 4 + Int(policyUriLength)
        offset += 4 + Int(policyUriLength)
        
        // Read senderCertificate length
        guard let certLength = buffer.getInteger(at: offset, endianness: .little, as: UInt32.self) else {
            return totalSize
        }
        
        #if false
        #endif
        
        if certLength == UInt32.max {
            totalSize += 4  // Placeholder
            offset += 4
        } else {
            totalSize += 4 + Int(certLength)
            offset += 4 + Int(certLength)
        }
        
        // Read receiverCertificateThumbprint length
        guard let thumbLength = buffer.getInteger(at: offset, endianness: .little, as: UInt32.self) else {
            #if false
            #endif
            return totalSize
        }
        
        #if false
        #endif
        
        if thumbLength == UInt32.max {
            totalSize += 4  // Placeholder
        } else {
            totalSize += 4 + Int(thumbLength)
        }
        
        return totalSize
    }
    
    var securityHeaderSize: Int { 
        // Calculate without accessing remoteCertificate to avoid crash
        // This is used in other calculations where we need an estimate
        if state.isFirstConnection {
            // First connection with .none security: policyUri + 2 placeholders
            // "http://opcfoundation.org/UA/SecurityPolicy#None" = 47 chars
            return 4 + 47 + 4 + 4  // = 59 bytes
        } else {
            // Subsequent connection with actual security
            // "http://opcfoundation.org/UA/SecurityPolicy#Basic256Sha256" = 57 chars
            // Certificate 1166 bytes, receiverCertificateThumbprint is always NULL (4 bytes placeholder)
            return 4 + 57 + 4 + 1166 + 4  // = 1235 bytes
        }
    }

    var cipherTextBlockSize: Int { 
        // Asymmetric (RSA-2048 with OAEP-SHA256): 256 bytes
        // Symmetric (AES-256-CBC): 16 bytes
        if state.hasSymmetricKeys {
            return 16  // AES-256-CBC block size
        } else {
            return 256  // RSA-2048 ciphertext size
        }
    }

    var plainTextBlockSize: Int { 
        // Asymmetric (RSA-2048 with OAEP-SHA256): 256 - 66 = 190 bytes
        // Symmetric (AES-256-CBC): 16 bytes (same as ciphertext for symmetric)
        if state.hasSymmetricKeys {
            return 16  // AES-256-CBC block size
        } else {
            return 190  // RSA-2048 plaintext capacity
        }
    }
}
