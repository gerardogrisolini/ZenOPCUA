//
//  SecurityPolicy.swift
//
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation
import NIO
//import CryptorRSA
#if os(Linux)
import Crypto
#else
import CryptoKit
#endif


//public typealias KeyPair = (privateKey: CryptorRSA.PrivateKey, publicKey: CryptorRSA.PublicKey)

class SecurityPolicy {
//    var clientPrivateKey: CryptorRSA.PrivateKey!
//    var clientPublicKey: CryptorRSA.PublicKey!
//    var serverPublicKey: CryptorRSA.PublicKey!
//    var clientPrivateKey: SecKey!
//    var clientPublicKey: SecKey!
//    var serverPublicKey: SecKey!
    
    var securityKeys: SecurityKeys? = nil
    var clientNonce: [UInt8] = []
    var localPrivateKey: Data = Data()
    var localCertificate: Data = Data()
    var localCertificateThumbprint: Data = Data()
    var remoteCertificate: Data = Data()
    var remoteCertificateThumbprint: Data = Data()
    
    let securityPolicyUri: String
    let symmetricSignatureAlgorithm: SecurityAlgorithm
    let symmetricEncryptionAlgorithm: SecurityAlgorithm
    let asymmetricSignatureAlgorithm: SecurityAlgorithm
    let asymmetricEncryptionAlgorithm: SecurityAlgorithm
    let asymmetricKeyWrapAlgorithm: SecurityAlgorithm
    let keyDerivationAlgorithm: SecurityAlgorithm
    let certificateSignatureAlgorithm: SecurityAlgorithm
    
    convenience init() {
        self.init(securityPolicyUri: SecurityPolicies.none.uri)
    }

    init(securityPolicyUri: String) {
        self.securityPolicyUri = securityPolicyUri
        switch securityPolicyUri.securityPolicy {
        case .basic128Rsa15:
            self.symmetricSignatureAlgorithm = .hmacSha1
            self.symmetricEncryptionAlgorithm = .aes128
            self.asymmetricSignatureAlgorithm = .rsaSha1
            self.asymmetricEncryptionAlgorithm = .rsa15
            self.asymmetricKeyWrapAlgorithm = .kwRsa15
            self.keyDerivationAlgorithm = .pSha1
            self.certificateSignatureAlgorithm = .sha1

        case .basic256:
            self.symmetricSignatureAlgorithm = .hmacSha1
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha1
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .kwRsaOaep
            self.keyDerivationAlgorithm = .pSha1
            self.certificateSignatureAlgorithm = .sha1

        case .basic256Sha256:
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .kwRsaOaep
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        case .aes128Sha256RsaOaep:
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .none
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        case .aes256Sha256RsaPss:
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256Pss
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha256
            self.asymmetricKeyWrapAlgorithm = .none
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        default:
            self.symmetricSignatureAlgorithm = .none
            self.symmetricEncryptionAlgorithm = .none
            self.asymmetricSignatureAlgorithm = .none
            self.asymmetricEncryptionAlgorithm = .none
            self.asymmetricKeyWrapAlgorithm = .none
            self.keyDerivationAlgorithm = .none
            self.certificateSignatureAlgorithm = .none
        }
    }

    private static func generateNonce(_ lenght: Int) -> Data {
//        let nonce = NSMutableData(length: lenght)!
//        let result = SecRandomCopyBytes(kSecRandomDefault, nonce.length, nonce.mutableBytes)
//        if result == errSecSuccess {
//            return nonce as Data
//        } else {
            return Data(repeating: UInt8.random(in: 0...255), count: lenght)
//        }
    }

    func loadLocalCertificate(certificate: String? = nil, privateKey: String? = nil) {
        if localCertificate.count == 0, let certificateFile = certificate, let privateKeyFile = privateKey {
            if securityPolicyUri.securityPolicy != .none {
                self.clientNonce.append(contentsOf: SecurityPolicy.generateNonce(32))
            }

            do {
                let certificateData = try Data(contentsOf: URL(fileURLWithPath: certificateFile))
                localCertificate = dataFromPEM(data: certificateData)
                localCertificateThumbprint = Data(Insecure.SHA1.hash(data: localCertificate))
                //clientPublicKey = try CryptorRSA.createPublicKey(extractingFrom: certificateData)
                //clientPublicKey = try P256.Signing.PublicKey(rawRepresentation: clientCertificate)//.suffix(65))
                //clientPublicKey = publicKeyFromData(certificate: clientCertificate)
            } catch {
                print("localCertificateAndPublicKey: \(error)")
            }

            do  {
                localPrivateKey = try Data(contentsOf: URL(fileURLWithPath: privateKeyFile))
                //clientPrivateKey = try CryptorRSA.createPrivateKey(with: privateKeyData)
                //clientPrivateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
            } catch {
                print("localPrivateKey: \(error)")
            }
        }
    }

    func loadRemoteCertificate(data: [UInt8]) {
        remoteCertificate.append(contentsOf: data) //Data(OPCUAHandler.endpoint.serverCertificate)
        remoteCertificateThumbprint = Data(Insecure.SHA1.hash(data: remoteCertificate))
        //let pemString = CryptorRSA.convertDerToPem(from: d, type: .publicType)
        //print(pemString)
        //let key = publicKeyFromData(certificate: data)!
        //serverPublicKey = CryptorRSA.PublicKey(with: key)
    }

//    func privateKeyFromData(data: Data, withPassword password: String = "") -> SecKey? {
//        let priKeyECData = dataFromPEM(data: data)
//
//        let keyDict: [CFString: Any] = [
//            kSecAttrKeyType: kSecAttrKeyTypeRSA,
//            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
//            kSecAttrKeySizeInBits: 2048,
//            kSecImportExportPassphrase as CFString: password,
//            kSecReturnPersistentRef: false
//        ]
//        var error: Unmanaged<CFError>?
//        let secKey = SecKeyCreateWithData(priKeyECData as CFData, keyDict as CFDictionary, &error)
//        return secKey
//    }

    
//    func publicKeyFromData(certificate: Data) -> SecKey? {
//        var publicKey: SecKey?
//        var trust: SecTrust?
//
//        guard let cert = SecCertificateCreateWithData(kCFAllocatorDefault, certificate as CFData) else { return nil }
//
//        let policy = SecPolicyCreateBasicX509()
//        let status = SecTrustCreateWithCertificates(cert, policy, &trust)
//
//        if status == errSecSuccess, let trust = trust {
//            publicKey = SecTrustCopyPublicKey(trust)!
//        }
//
//        return publicKey
//    }
    
    fileprivate func dataFromPEM(pemString: String) -> Data {
        let rows = pemString.split(separator: "\n")
        let joined = rows[1...(rows.count - 2)].joined().data(using: .ascii)!
        return Data(base64Encoded: joined, options: .ignoreUnknownCharacters)!
    }

    fileprivate func dataFromPEM(data: Data) -> Data {
        dataFromPEM(pemString: String(data: data, encoding: .ascii)!)
    }
    
    var securityHeaderSize: Int {
        return SECURE_MESSAGE_HEADER_SIZE +
            securityPolicyUri.count +
            localCertificate.count +
            remoteCertificateThumbprint.count
    }

    var securityRemoteHeaderSize: Int {
        return SECURE_MESSAGE_HEADER_SIZE +
            securityPolicyUri.count +
            remoteCertificate.count +
            localCertificateThumbprint.count
    }
        
    func getAsymmetricKeyLength(publicKey: SecKey) -> Int {
//        return SecKeyGetBlockSize(publicKey) * 8
        return 256 * 8
    }

    var remoteAsymmetricSignatureSize: Int {
//        guard let serverPublicKey = publicKeyFromData(certificate: remoteCertificate) else { return 0 }
//
//        switch asymmetricSignatureAlgorithm {
//        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
//            return (getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8
//        default:
            return 0
//        }
    }

    var asymmetricSignatureSize: Int {
//        guard let clientPublicKey = publicKeyFromData(certificate: localCertificate) else { return 0 }
//
//        switch asymmetricSignatureAlgorithm {
//        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
//            return (getAsymmetricKeyLength(publicKey: clientPublicKey) + 7) / 8
//        default:
            return 0
//        }
    }

    var asymmetricCipherTextBlockSize: Int {
//        guard let serverPublicKey = publicKeyFromData(certificate: remoteCertificate) else { return 1 }
//
//        switch (asymmetricEncryptionAlgorithm) {
//        case .rsa15, .rsaOaepSha1, .rsaOaepSha256:
//            return (getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8
//        default:
            return 1
//        }
    }
    
    var asymmetricPlainTextBlockSize: Int {
//        guard let serverPublicKey = publicKeyFromData(certificate: remoteCertificate) else { return 1 }
//
//        switch (asymmetricEncryptionAlgorithm) {
//        case .rsa15:
//            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 11
//        case .rsaOaepSha1:
//            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 42
//        case .rsaOaepSha256:
//            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 66
//        default:
            return 1
//        }
    }
    
    var symmetricBlockSize: Int {
        switch symmetricEncryptionAlgorithm {
        case .aes128, .aes256:
            return 16
        default:
            return 1
        }
    }

    var symmetricSignatureSize: Int {
        switch symmetricSignatureAlgorithm {
        case .hmacSha1:
                return 20
        case .hmacSha256:
                return 32
            default:
                return 0
        }
    }

    var symmetricSignatureKeySize: Int {
        switch securityPolicyUri.securityPolicy {
        case .none:
            return 0
        case .basic128Rsa15:
            return 16
        case .basic256:
            return 24
        case .basic256Sha256, .aes128Sha256RsaOaep, .aes256Sha256RsaPss:
            return 32
        default:
            return 0
        }
    }
    
    var symmetricEncryptionKeySize: Int {
        switch securityPolicyUri.securityPolicy {
        case .none:
            return 0
        case .basic128Rsa15, .aes128Sha256RsaOaep:
            return 16
        case .basic256, .basic256Sha256, .aes256Sha256RsaPss:
            return 32
        default:
            return 0
        }
    }
    
    var isAsymmetricSigningEnabled: Bool {
        return OPCUAHandler.messageSecurityMode != .none && localCertificate.count > 0
    }
    
    var isSymmetricSigningEnabled: Bool {
        return localCertificate.count > 0 && OPCUAHandler.messageSecurityMode != .none
            && (OPCUAHandler.messageSecurityMode == .sign || OPCUAHandler.messageSecurityMode == .signAndEncrypt)
    }
    
    var isAsymmetricEncryptionEnabled: Bool {
        return OPCUAHandler.messageSecurityMode != .none
            && localCertificate.count > 0
            && remoteCertificate.count > 0
    }

   var isSymmetricEncryptionEnabled: Bool {
        return remoteCertificate.count > 0 && OPCUAHandler.messageSecurityMode != .none
            && OPCUAHandler.messageSecurityMode == .signAndEncrypt
    }

    var isSigningEnabled: Bool { OPCUAHandler.messageSecurityMode != .none && localCertificate.count > 0 }
    var isEncryptionEnabled: Bool { OPCUAHandler.messageSecurityMode == .signAndEncrypt && localCertificate.count > 0 }
    var isAsymmetric: Bool { securityKeys == nil }
    
    
//    func generateKeyPair(ofSize bits: UInt) throws -> KeyPair? {
//        let pubKeyAttrs = [ kSecAttrIsPermanent as String: true ]
//        let privKeyAttrs = [ kSecAttrIsPermanent as String: true ]
//        let params: NSDictionary = [ kSecAttrKeyType as String : kSecAttrKeyTypeRSA as String,
//                       kSecAttrKeySizeInBits as String : bits,
//                       kSecPublicKeyAttrs as String : pubKeyAttrs,
//                       kSecPrivateKeyAttrs as String : privKeyAttrs ]
//        var pubKey: SecKey?
//        var privKey: SecKey?
//        let status = SecKeyGeneratePair(params, &pubKey, &privKey)
//        switch status {
//        case noErr:
//            return (privKey!, pubKey!)
//        default:
//            return nil
//        }
//    }

    
    /* Common */

//    func crypt(data: [UInt8]) throws -> [UInt8] {
//        try isAsymmetric ? cryptAsymmetric(data: data) : cryptSymmetric(data: data)
//    }
//
//    func decrypt(data: [UInt8]) throws -> [UInt8] {
//        try isAsymmetric ? decryptAsymmetric(data: data) : decryptSymmetric(data: data)
//    }

    func sign(data: Data) throws -> Data {
        try isAsymmetric ? signAsymmetric(data: data) : signSymmetric(data: data)
    }

    func signVerify(signature: Data, data: Data) -> Bool {
        isAsymmetric ? signVerifyAsymmetric(signature: signature, data: data) : signVerifySymmetric(signature: signature, data: data)
    }
    
    
    /* Asymmetric */

    func signAsymmetric(data: Data) throws -> Data {
//        let algorithm: SecKeyAlgorithm
//        switch asymmetricSignatureAlgorithm {
//        case .rsaSha1:
//            algorithm = .rsaSignatureMessagePKCS1v15SHA1
//        case .rsaSha256:
//            algorithm = .rsaSignatureMessagePKCS1v15SHA256
//        default:
//            algorithm = .rsaSignatureMessagePSSSHA256
//        }
//
//        let clientPrivateKey = privateKeyFromData(data: localPrivateKey)!
//
//        guard SecKeyIsAlgorithmSupported(clientPrivateKey, .sign, algorithm) else {
//            throw OPCUAError.generic("unsupported sign algorithm")
//        }
//
//        var error: Unmanaged<CFError>?
//        guard let signature = SecKeyCreateSignature(clientPrivateKey,
//                                                    algorithm,
//                                                    data as CFData,
//                                                    &error) as Data? else {
//                                                        throw error!.takeRetainedValue() as Error
//        }
//
//        return signature
//
////        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: localPrivateKey)
////        let signature = try privateKey.signature(for: data)
////        return signature.rawRepresentation
        
        return data
    }
    
    func signVerifyAsymmetric(signature: Data, data: Data) -> Bool {
//        let algorithm: SecKeyAlgorithm
//        switch asymmetricSignatureAlgorithm {
//        case .rsaSha1:
//            algorithm = .rsaSignatureMessagePKCS1v15SHA1
//        case .rsaSha256:
//            algorithm = .rsaSignatureMessagePKCS1v15SHA256
//        default:
//            algorithm = .rsaSignatureMessagePSSSHA256
//        }
//
//        let clientPublicKey = publicKeyFromData(certificate: localCertificate)!
//
//        guard SecKeyIsAlgorithmSupported(clientPublicKey, .verify, algorithm) else {
//            print("unsupported verify algorithm")
//            return false
//        }
//
//        var error: Unmanaged<CFError>?
//        guard SecKeyVerifySignature(clientPublicKey,
//                                    algorithm,
//                                    data as CFData,
//                                    signature as CFData,
//                                    &error) else {
//                                        print(error!.takeRetainedValue() as Error)
//                                        return false
//                                    }
//        return true
//
////        do {
////            let publicKey = try P256.Signing.PublicKey(rawRepresentation: remoteCertificate)
////            let sign = try P256.Signing.ECDSASignature(rawRepresentation: signature)
////            return publicKey.isValidSignature(sign, for: data)
////        } catch {
////            print("signVerifyAsymmetric: \(error)")
////            return false
////        }
        
        return true
    }
    
    func cryptAsymmetric(data: [UInt8]) throws -> [UInt8] {
//        let algorithm: SecKeyAlgorithm
//        switch asymmetricEncryptionAlgorithm {
//        case .rsaOaepSha1:
//            algorithm = .rsaEncryptionOAEPSHA1
//        case .rsaOaepSha256:
//            algorithm = .rsaEncryptionOAEPSHA256
//        default:
//            algorithm = .rsaEncryptionPKCS1
//        }
//
//        let key = publicKeyFromData(certificate: remoteCertificate)!
//        var error: Unmanaged<CFError>?
//        guard let cipherText = SecKeyCreateEncryptedData(
//            key,
//            algorithm,
//            Data(data) as CFData,
//            &error) as Data? else {
//            throw error!.takeRetainedValue() as Error
//        }
//
//        return [UInt8](cipherText)
//
//        //let savedKey = key.withUnsafeBytes {Data(Array($0)).base64EncodedString()}
        
        return data
    }
        
    func decryptAsymmetric(data: [UInt8]) throws -> [UInt8] {
//        let algorithm: SecKeyAlgorithm
//        switch asymmetricEncryptionAlgorithm {
//        case .rsaOaepSha1:
//            algorithm = .rsaEncryptionOAEPSHA1
//        case .rsaOaepSha256:
//            algorithm = .rsaEncryptionOAEPSHA256
//        default:
//            algorithm = .rsaEncryptionPKCS1
//        }
//
//        let key = privateKeyFromData(data: localPrivateKey)!
//        var error: Unmanaged<CFError>?
//        guard let plainData = SecKeyCreateDecryptedData(
//            key,
//            algorithm,
//            Data(data) as CFData,
//            &error) as Data? else {
//            throw error!.takeRetainedValue() as Error
//        }
//
//        return [UInt8](plainData)
        
        return data
    }
    

    /* Symmetric */

    func cryptSymmetric(data: [UInt8]) throws -> [UInt8] {
        let sk = SymmetricKey(data: SHA256.hash(data: securityKeys!.serverKeys.encryptionKey))
        let iv = try AES.GCM.Nonce(data: securityKeys!.serverKeys.initializationVector)
        let encryptedData = try AES.GCM.seal(data, using: sk, nonce: iv)
        return [UInt8](encryptedData.ciphertext)
    }

    func decryptSymmetric(data: [UInt8]) throws -> [UInt8] {
        let sk = SymmetricKey(data: SHA256.hash(data: securityKeys!.clientKeys.encryptionKey))
        let iv = try AES.GCM.Nonce(data: securityKeys!.clientKeys.initializationVector)
        let sealedBox = try AES.GCM.SealedBox(nonce: iv, ciphertext: data, tag: Data())
        let decryptedData = try AES.GCM.open(sealedBox, using: sk)
        return [UInt8](decryptedData)
    }
    
    func signSymmetric(data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: securityKeys!.clientKeys.signatureKey))
        let data = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(data)
    }

    func signVerifySymmetric(signature: Data, data: Data) -> Bool {
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: securityKeys!.serverKeys.signatureKey))
        return HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: data, using: symmetricKey)
    }
    
    func generateSecurityKeys(serverNonce: [UInt8], clientNonce: [UInt8]) {
        assert(clientNonce.count > 0)
        assert(serverNonce.count > 0)

        let clientSignatureKey = createPShaKey(serverNonce, clientNonce, 0, symmetricSignatureKeySize)
        let clientEncryptionKey = createPShaKey(serverNonce, clientNonce, symmetricSignatureKeySize, symmetricEncryptionKeySize)
        let clientInitializationVector = createPShaKey(serverNonce, clientNonce, symmetricSignatureKeySize + symmetricEncryptionKeySize, symmetricBlockSize)
        let serverSignatureKey = createPShaKey(clientNonce, serverNonce, 0, symmetricSignatureKeySize)
        let serverEncryptionKey = createPShaKey(clientNonce, serverNonce, symmetricSignatureKeySize, symmetricEncryptionKeySize)
        let serverInitializationVector = createPShaKey(clientNonce, serverNonce, symmetricSignatureKeySize + symmetricEncryptionKeySize, symmetricBlockSize)

        securityKeys = SecurityKeys(
            clientKeys: SecretKeys(
                signatureKey: clientSignatureKey,
                encryptionKey: clientEncryptionKey,
                initializationVector: clientInitializationVector
            ),
            serverKeys: SecretKeys(
                signatureKey: serverSignatureKey,
                encryptionKey: serverEncryptionKey,
                initializationVector: serverInitializationVector
            )
        )
    }

    private func createPShaKey(
        _ secret: [UInt8],
        _ seed: [UInt8],
        _ offset: Int,
        _ length: Int) -> Data {

        var required = offset + length
        var out = Data(repeating: 0, count: required)
        var off = 0
        var toCopy: Int
        var a = Data(seed)
        var tmp: Data
        
        if keyDerivationAlgorithm == .pSha1 {
            let key = SymmetricKey(data: Insecure.SHA1.hash(data: secret))
            var mac = HMAC<Insecure.SHA1>(key: key)
            while required > 0 {
                mac.update(data: a)
                a = Data(mac.finalize())
                mac = .init(key: key)
                mac.update(data: a)
                mac.update(data: seed)
                tmp = Data(mac.finalize())
                toCopy = min(required, tmp.count)
                out.append(contentsOf: tmp[0..<toCopy])
                off += toCopy
                required -= toCopy
            }
        } else {
            let key = SymmetricKey(data: SHA256.hash(data: secret))
            var mac = HMAC<SHA256>(key: key)
            while required > 0 {
                mac.update(data: a)
                a = Data(mac.finalize())
                mac = .init(key: key)
                mac.update(data: a)
                mac.update(data: seed)
                tmp = Data(mac.finalize())
                toCopy = min(required, tmp.count)
                out.append(contentsOf: tmp[0..<toCopy])
                off += toCopy
                required -= toCopy
            }
        }

        return out[offset..<offset+length]
    }
}

struct SecurityKeys {
    let clientKeys: SecretKeys
    let serverKeys: SecretKeys
}

struct SecretKeys {
    let signatureKey: Data
    let encryptionKey: Data
    let initializationVector: Data
}
