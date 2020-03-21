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
        out.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
        out.writeBytes(value.head.messageSize.bytes)
        out.writeBytes(value.body)
    }
    
    func signAndEncrypt() {

        
        let encrypted: Bool = OPCUAHandler.messageSecurityMode == .signAndEncrypt

        let securityHeaderSize: Int = getSecurityHeaderSize()
        let cipherTextBlockSize: Int = getCipherTextBlockSize()
        let plainTextBlockSize: Int = getPlainTextBlockSize()
        let signatureSize: Int = getSignatureSize()

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
