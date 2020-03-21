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
    var publicKey: SecKey? = nil
    var privateKey: SecKey? = nil
    var localCertificateChain: Data = Data()
    
    lazy var remoteCertificateThumbprint: Data = {
        let thumbprint = Insecure.SHA1.hash(data: OPCUAHandler.endpoint.serverCertificate)
        return thumbprint.data
    }()
    
    
    init() {
        securityPolicy = SecurityPolicy(securityPolicyUri: OPCUAHandler.securityPolicy.uri)
        
        if OPCUAHandler.messageSecurityMode != .none,
            let certificateFile = OPCUAHandler.certificate,
            let privateKeyFile = OPCUAHandler.privateKey {
            
            if let certificateDate = try? Data(contentsOf: URL(fileURLWithPath: certificateFile)) {
                publicKey = securityPolicy.publicKeyFromData(certificate: certificateDate)
                localCertificateChain.append(contentsOf: certificateDate)
            }
            if let privateKeyData = try? Data(contentsOf: URL(fileURLWithPath: privateKeyFile)) {
                privateKey = securityPolicy.privateKeyFromData(privateKey: privateKeyData)
            }
        }
    }
    
    public func encode(data value: OPCUAFrame, out: inout ByteBuffer) throws {
        //print(value)
        if OPCUAHandler.messageSecurityMode == .none {
            out.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
            out.writeBytes(value.head.messageSize.bytes)
            out.writeBytes(value.body)
        } else {
            var byteBuffer = byteBufferAllocator.buffer(capacity: value.body.count + 8)
            byteBuffer.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
            byteBuffer.writeBytes(value.head.messageSize.bytes)
            byteBuffer.writeBytes(value.body)
            signAndEncrypt(byteBuffer: byteBuffer, out: &out)
        }
    }
    
    func signAndEncrypt(byteBuffer: ByteBuffer, out: inout ByteBuffer) {
        
        let SEQUENCE_HEADER_SIZE: Int = 8
        let SECURE_MESSAGE_HEADER_SIZE: Int = 12
        
        let encrypted: Bool = OPCUAHandler.messageSecurityMode == .signAndEncrypt

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

        
        /*
        /* Padding and Signature */
        if (encrypted) {
            writePadding(cipherTextBlockSize, paddingSize, chunkBuffer);
        }

        if (isSigningEnabled(channel)) {
            ByteBuffer chunkNioBuffer = chunkBuffer.nioBuffer(0, chunkBuffer.writerIndex());

            byte[] signature = signChunk(channel, chunkNioBuffer);

            chunkBuffer.writeBytes(signature);
        }

        /* Encryption */
        if (encrypted) {
            chunkBuffer.readerIndex(SECURE_MESSAGE_HEADER_SIZE + securityHeaderSize);

            assert (chunkBuffer.readableBytes() % plainTextBlockSize == 0);

            try {
                int blockCount = chunkBuffer.readableBytes() / plainTextBlockSize;

                ByteBuffer chunkNioBuffer = chunkBuffer.nioBuffer(
                    chunkBuffer.readerIndex(), blockCount * cipherTextBlockSize);

                ByteBuf copyBuffer = chunkBuffer.copy();
                ByteBuffer plainTextNioBuffer = copyBuffer.nioBuffer();

                Cipher cipher = getCipher(channel);

                if (isAsymmetric()) {
                    for (int blockNumber = 0; blockNumber < blockCount; blockNumber++) {
                        int position = blockNumber * plainTextBlockSize;
                        int limit = (blockNumber + 1) * plainTextBlockSize;
                        ((Buffer) plainTextNioBuffer).position(position);
                        ((Buffer) plainTextNioBuffer).limit(limit);

                        int bytesWritten = cipher.doFinal(plainTextNioBuffer, chunkNioBuffer);

                        assert (bytesWritten == cipherTextBlockSize);
                    }
                } else {
                    cipher.doFinal(plainTextNioBuffer, chunkNioBuffer);
                }

                copyBuffer.release();
            } catch (GeneralSecurityException e) {
                throw new UaException(StatusCodes.Bad_SecurityChecksFailed, e);
            }
        }

        chunkBuffer.readerIndex(0).writerIndex(chunkSize);
        */
        
        
        
//        let privateKey = try? Data(contentsOf: URL(fileURLWithPath: privateKeyFile)) {
//        let signed = try! securityPolicy.sign(dataToSign: dataToSign, privateKey: privateKey, clientCertificate: Data(senderCertificate[4...]))
//        let len = UInt32(signed.count).bytes

        
    }
    
    func getSecurityHeaderSize() -> Int {
        return 12 + OPCUAHandler.securityPolicy.uri.count +
            localCertificateChain.count +
            remoteCertificateThumbprint.count
    }

    func getCipherTextBlockSize() -> Int {
        return securityPolicy.getAsymmetricCipherTextBlockSize(publicKey: publicKey!, algorithm: securityPolicy.asymmetricEncryptionAlgorithm)
    }

    func getPlainTextBlockSize() -> Int {
        return securityPolicy.getAsymmetricPlainTextBlockSize(publicKey: publicKey!, algorithm: securityPolicy.asymmetricEncryptionAlgorithm)
    }

    func getSignatureSize() -> Int {
        return securityPolicy.getAsymmetricSignatureSize(publicKey: publicKey!, algorithm: securityPolicy.asymmetricSignatureAlgorithm)
    }
}
