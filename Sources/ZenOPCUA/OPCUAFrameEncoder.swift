//
//  OPCUAFrameEncoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import Foundation
import CryptoKit
import NIO

public final class OPCUAFrameEncoder: MessageToByteEncoder {
    public typealias OutboundIn = OPCUAFrame

    let byteBufferAllocator = ByteBufferAllocator()
    let securityPolicy: SecurityPolicy
    var privateKeyData: Data = Data()
    var localCertificate: Data = Data()
    
    lazy var serverPublicKey: SecKey? = {
        return securityPolicy.publicKeyFromData(certificate: Data(OPCUAHandler.endpoint.serverCertificate))
    }()

    lazy var clientPublicKey: SecKey? = {
        return securityPolicy.publicKeyFromData(certificate: Data(localCertificate))
    }()
    
    lazy var remoteCertificateThumbprint: Data = {
        return Insecure.SHA1.hash(data: OPCUAHandler.endpoint.serverCertificate).data
    }()
    
    lazy var localCertificateThumbprint: Data = {
        return Insecure.SHA1.hash(data: localCertificate).data
    }()

    init() {
        securityPolicy = SecurityPolicy(securityPolicyUri: OPCUAHandler.securityPolicy.uri)
        
        if OPCUAHandler.messageSecurityMode != .none,
            let certificateFile = OPCUAHandler.certificate,
            let privateKeyFile = OPCUAHandler.privateKey {
            
            if let certificateDate = try? Data(contentsOf: URL(fileURLWithPath: certificateFile)) {
                let certificate = securityPolicy.getCertificateFromPem(data: certificateDate)
                localCertificate.append(contentsOf: certificate)
            }
            if let privateKeyData = try? Data(contentsOf: URL(fileURLWithPath: privateKeyFile)) {
                //privateKey = securityPolicy.privateKeyFromData(privateKey: privateKeyData)
                self.privateKeyData = privateKeyData
            }
        }
    }
    
    public func encode(data value: OPCUAFrame, out: inout ByteBuffer) throws {
        //print(value.head)
        if OPCUAHandler.messageSecurityMode == .none || OPCUAHandler.isAcknowledgeSecure || value.head.messageType == .hello {
            out.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
            out.writeBytes(value.head.messageSize.bytes)
            out.writeBytes(value.body)
        } else {
            var byteBuffer = byteBufferAllocator.buffer(capacity: value.body.count + 8)
            byteBuffer.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
            byteBuffer.writeBytes(value.head.messageSize.bytes)
            byteBuffer.writeBytes(value.body)
            try signAndEncrypt(messageBuffer: byteBuffer, out: &out)
        }
    }
    
    func signAndEncrypt(messageBuffer: ByteBuffer, out: inout ByteBuffer) throws {
        
        let SEQUENCE_HEADER_SIZE: Int = 8
        let SECURE_MESSAGE_HEADER_SIZE: Int = 12
        
        let encrypted: Bool = OPCUAHandler.messageSecurityMode != .none //.signAndEncrypt

        let securityHeaderSize: Int = getSecurityHeaderSize()
        let cipherTextBlockSize: Int = getCipherTextBlockSize()
        let plainTextBlockSize: Int = getPlainTextBlockSize()
        let signatureSize: Int = getSignatureSize()

        let maxChunkSize = OPCUAHandler.bufferSize
        let paddingOverhead = encrypted ? (cipherTextBlockSize > 256 ? 2 : 1) : 0

        let maxCipherTextSize = maxChunkSize - SECURE_MESSAGE_HEADER_SIZE - securityHeaderSize
        let maxCipherTextBlocks = maxCipherTextSize / cipherTextBlockSize
        let maxPlainTextSize = maxCipherTextBlocks * plainTextBlockSize
        let maxBodySize = maxPlainTextSize - SEQUENCE_HEADER_SIZE - paddingOverhead - signatureSize

        assert (maxPlainTextSize + securityHeaderSize + SECURE_MESSAGE_HEADER_SIZE <= maxChunkSize)

        let header = SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize
        var readedBytes = header + SEQUENCE_HEADER_SIZE
        while readedBytes < messageBuffer.readableBytes {
            let bodySize = min(messageBuffer.readableBytes - readedBytes, maxBodySize)

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

            assert (plainTextContentSize % plainTextBlockSize == 0)

            let chunkSize = SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize +
                (plainTextContentSize / plainTextBlockSize) * cipherTextBlockSize

            assert (chunkSize <= maxChunkSize)

            var chunkBuffer = byteBufferAllocator.buffer(capacity: chunkSize)
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: 0, length: header + SEQUENCE_HEADER_SIZE)!)
            chunkBuffer.writeBytes(messageBuffer.getBytes(at: readedBytes, length: bodySize)!)
            readedBytes += bodySize

            /* Padding and Signature */
            if encrypted {
                print("writePadding: \(paddingSize)")
                let l = chunkBuffer.readableBytes
                writePadding(cipherTextBlockSize, paddingSize, &chunkBuffer)
                print(chunkBuffer.readableBytes - l)
            }

            if OPCUAHandler.messageSecurityMode != .none {
                let dataToSign = chunkBuffer.getBytes(at: 0, length: chunkBuffer.writerIndex)!
                let signature = try securityPolicy.sign(dataToSign: dataToSign, privateKey: privateKeyData, clientCertificate: localCertificate)
                chunkBuffer.writeBytes(signature)
            }

            
            /* Encryption */
            if (encrypted) {
                out.writeBytes(chunkBuffer.getBytes(at: 0, length: header + SEQUENCE_HEADER_SIZE)!)
                
                assert ((chunkBuffer.readableBytes - header) % plainTextBlockSize == 0)

                let blockCount = (chunkBuffer.readableBytes - header) / plainTextBlockSize

                var chunkNioBuffer = byteBufferAllocator.buffer(capacity: blockCount * cipherTextBlockSize)
                
                let serverCertificate = Data(OPCUAHandler.endpoint.serverCertificate)

                for blockNumber in 0..<blockCount {
                    let position = blockNumber * plainTextBlockSize
                    let limit = (blockNumber + 1) * plainTextBlockSize
                    let dataToEncrypt = chunkBuffer.getBytes(at: position + header, length: limit)!
                    let dataEncrypted = try securityPolicy.crypt(dataToEncrypt: dataToEncrypt, serverCertificate: serverCertificate)

                    assert (dataEncrypted.count == cipherTextBlockSize)
                    chunkNioBuffer.writeBytes(dataEncrypted)
                }
                
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

        for _ in 0..<paddingSize {
            buffer.writeBytes([UInt8(paddingSize)])
        }

        if cipherTextBlockSize > 256 {
            // Replace the last byte with the MSB of the 2-byte padding length
            let paddingLengthMsb: Int = paddingSize >> 8
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
            buffer.writeBytes(paddingLengthMsb.bytes)
        }
    }

    func getSecurityHeaderSize() -> Int {
        return 12 + OPCUAHandler.securityPolicy.uri.count +
            localCertificate.count +
            remoteCertificateThumbprint.count
    }

    func getCipherTextBlockSize() -> Int {
        return securityPolicy.getAsymmetricCipherTextBlockSize(
            publicKey: serverPublicKey!,
            algorithm: securityPolicy.asymmetricEncryptionAlgorithm
        )
    }

    func getPlainTextBlockSize() -> Int {
        return securityPolicy.getAsymmetricPlainTextBlockSize(
            publicKey: serverPublicKey!,
            algorithm: securityPolicy.asymmetricEncryptionAlgorithm
        )
    }

    func getSignatureSize() -> Int {
        return securityPolicy.getAsymmetricSignatureSize(
            publicKey: clientPublicKey!,
            algorithm: securityPolicy.asymmetricSignatureAlgorithm
        )
    }
}
