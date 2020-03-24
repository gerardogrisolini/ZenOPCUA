//
//  SecurityPolicy.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation
import CryptoKit
import NIO

public enum SecurityPolicies: String {
    case invalid = "invalid"
    case none = "None"
    case basic256 = "Basic256"
    case basic256Sha256 = "Basic256Sha256"
    case basic128Rsa15 = "Basic128Rsa15"
    case aes256Sha256RsaPss = "Aes256_Sha256_RsaPss"
    case aes128Sha256RsaOaep = "Aes128_Sha256_RsaOaep"
}

extension SecurityPolicies {
    var uri: String {
        if self == .invalid { return self.rawValue }
        return "http://opcfoundation.org/UA/SecurityPolicy#\(self.rawValue)"
    }
}

enum SecurityAlgorithm: String {
    case none = ""
    
    /**
     * Symmetric Signature; transformation to be used with {@link Mac#getInstance(String)}.
     */
    case hmacSha1 = "http://www.w3.org/2000/09/xmldsig#hmac-sha1,HmacSHA1"

    /**
     * Symmetric Signature; transformation to be used with {@link Mac#getInstance(String)}.
     */
    case hmacSha256 = "http://www.w3.org/2000/09/xmldsig#hmac-sha256,HmacSHA256"

    /**
     * Symmetric Encryption; transformation to be used with {@link Cipher#getInstance(String)}.
     */
    case aes128 = "http://www.w3.org/2001/04/xmlenc#aes128-cbc,AES/CBC/NoPadding"

    /**
     * Symmetric Encryption; transformation to be used with {@link Cipher#getInstance(String)}.
     */
    case aes256 = "http://www.w3.org/2001/04/xmlenc#aes256-cbc,AES/CBC/NoPadding"

    /**
     * Asymmetric Signature; transformation to be used with {@link Signature#getInstance(String)}.
     */
    case rsaSha1 = "http://www.w3.org/2000/09/xmldsig#rsa-sha1,SHA1withRSA"

    /**
     * Asymmetric Signature; transformation to be used with {@link Signature#getInstance(String)}.
     */
    case rsaSha256 = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256,SHA256withRSA"

    /**
     * Asymmetric Signature; transformation to be used with {@link Signature#getInstance(String)}.
     * <p>
     * Requires Bouncy Castle installed as a Security Provider.
     */
    case rsaSha256Pss = "http://opcfoundation.org/UA/security/rsa-pss-sha2-256,SHA256withRSA/PSS"

    /**
     * Asymmetric Encryption; transformation to be used with {@link Cipher#getInstance(String)}.
     */
    case rsa15 = "http://www.w3.org/2001/04/xmlenc#rsa-1_5,RSA/ECB/PKCS1Padding"

    /**
     * Asymmetric Encryption; transformation to be used with {@link Cipher#getInstance(String)}.
     */
    case rsaOaepSha1 = "http://www.w3.org/2001/04/xmlenc#rsa-oaep,RSA/ECB/OAEPWithSHA-1AndMGF1Padding"

    /**
     * Asymmetric Encryption; transformation to be used with {@link Cipher#getInstance(String)}.
     * <p>
     * Important note: the transformation used is "RSA/ECB/OAEPWithSHA256AndMGF1Padding" as opposed to
     * "RSA/ECB/OAEPWithSHA-256AndMGF1Padding".
     * <p>
     * While similar, the former is provided by Bouncy Castle whereas the latter is provided by SunJCE.
     * <p>
     * This is important because the BC version uses SHA256 in the padding while the SunJCE version uses Sha1.
     */
    case rsaOaepSha256 = "http://opcfoundation.org/UA/security/rsa-oaep-sha2-256,RSA/ECB/OAEPWithSHA256AndMGF1Padding"

    /**
     * Asymmetric Key Wrap
     */
    case kwRsa15 = "http://www.w3.org/2001/04/xmlenc#rsa-1_5"

    /**
     * Asymmetric Key Wrap
     */
    case kwRsaOaep = "http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p"

    /**
     * Key Derivation
     */
    case pSha1 = "http://docs.oasis-open.org/ws-sx/ws-secureconversation/200512/dk/p_sha1"

    /**
     * Key Derivation
     */
    case pSha256 = "http://docs.oasis-open.org/ws-sx/ws-secureconversation/200512/dk/p_sha256"

    /**
     * Cryptographic Hash; transformation to be used with {@link MessageDigest#getInstance(String)}.
     */
    case sha1 = "http://www.w3.org/2000/09/xmldsig#sha1,SHA-1"

    /**
     * Cryptographic Hash; transformation to be used with {@link MessageDigest#getInstance(String)}.
     */
    case sha256 = "http://www.w3.org/2001/04/xmlenc#sha256,SHA-256"
}

struct SecurityPolicy {
    let securityPolicyUri: String
    let symmetricSignatureAlgorithm: SecurityAlgorithm
    let symmetricEncryptionAlgorithm: SecurityAlgorithm
    let asymmetricSignatureAlgorithm: SecurityAlgorithm
    let asymmetricEncryptionAlgorithm: SecurityAlgorithm
    let asymmetricKeyWrapAlgorithm: SecurityAlgorithm
    let keyDerivationAlgorithm: SecurityAlgorithm
    let certificateSignatureAlgorithm: SecurityAlgorithm
    let symmetricKeyLength: Int
    
    init(securityPolicyUri: String) {
        self.securityPolicyUri = securityPolicyUri
        
        switch securityPolicyUri.securityPolicy {
        case .basic128Rsa15:
            self.symmetricKeyLength = 16
            self.symmetricSignatureAlgorithm = .hmacSha1
            self.symmetricEncryptionAlgorithm = .aes128
            self.asymmetricSignatureAlgorithm = .rsaSha1
            self.asymmetricEncryptionAlgorithm = .rsa15
            self.asymmetricKeyWrapAlgorithm = .kwRsa15
            self.keyDerivationAlgorithm = .pSha1
            self.certificateSignatureAlgorithm = .sha1

        case .basic256:
            self.symmetricKeyLength = 32
            self.symmetricSignatureAlgorithm = .hmacSha1
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha1
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .kwRsaOaep
            self.keyDerivationAlgorithm = .pSha1
            self.certificateSignatureAlgorithm = .sha1

        case .basic256Sha256:
            self.symmetricKeyLength = 32
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .kwRsaOaep
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        case .aes128Sha256RsaOaep:
            self.symmetricKeyLength = 32
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .none
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        case .aes256Sha256RsaPss:
            self.symmetricKeyLength = 32
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256Pss
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha256
            self.asymmetricKeyWrapAlgorithm = .none
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        default:
            self.symmetricKeyLength = 0
            self.symmetricSignatureAlgorithm = .none
            self.symmetricEncryptionAlgorithm = .none
            self.asymmetricSignatureAlgorithm = .none
            self.asymmetricEncryptionAlgorithm = .none
            self.asymmetricKeyWrapAlgorithm = .none
            self.keyDerivationAlgorithm = .none
            self.certificateSignatureAlgorithm = .none
        }
    }
    
//   private func privateKeyForCertificate(keyData: Data, withPassword password: String = "") -> SecKey? {
//        let priKeyECStriped = keyData[32..<keyData.count - 31]
//        print(String(data: priKeyECStriped, encoding: .utf8))
//
//        var privateKey: SecKey? = nil
//        let options : [String:String] = [kSecImportExportPassphrase as String:password]
//        var items : CFArray?
//        if SecPKCS12Import(data as CFData, options as CFDictionary, &items) == errSecSuccess {
//            if CFArrayGetCount(items) > 0 {
//                let d = unsafeBitCast(CFArrayGetValueAtIndex(items, 0),to: CFDictionary.self)
//                let k = Unmanaged.passUnretained(kSecImportItemIdentity as NSString).toOpaque()
//                let v = CFDictionaryGetValue(d, k)
//                let secIdentity = unsafeBitCast(v, to: SecIdentity.self)
//                if SecIdentityCopyPrivateKey(secIdentity, &privateKey) == errSecSuccess {
//                    return privateKey
//                }
//            }
//        }
//
//        return nil
//    }
    
    func getCertificateFromPem(data: Data) -> [UInt8] {
        let startIndex = "-----BEGIN CERTIFICATE-----".data(using: .utf8)!
        let lastIndex = "-----END CERTIFICATE-----".data(using: .utf8)!
        
        var index = 0
        for i in 0..<data.count {
            index = i + startIndex.count
            if data[i..<index] == startIndex {
                index += 1
                break
            }
        }
        
        // remove header, footer and newlines from pem string
        let pemWithoutHeaderFooterNewlines = data[index..<(data.count - lastIndex.count - 2)]
        //print(String(data: pemWithoutHeaderFooterNewlines, encoding: .utf8)!)

        let certData = Data(base64Encoded: pemWithoutHeaderFooterNewlines, options: Data.Base64DecodingOptions.ignoreUnknownCharacters)!
        
        return getCertificateEncoded(data: certData)
    }
    
    func getCertificateEncoded(data: Data) -> [UInt8] {
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData)!
        let encoded = SecCertificateCopyData(certificate) as Data
        return [UInt8](encoded)
    }
    
    func privateKeyFromData(privateKey: Data) -> SecKey? {
        let priKeyECStriped = privateKey[32..<privateKey.count - 31]
        //print(String(data: priKeyECStriped, encoding: .utf8)!)
        let priKeyECData = Data(base64Encoded: priKeyECStriped, options: Data.Base64DecodingOptions.ignoreUnknownCharacters)!

        let keyDict: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: priKeyECStriped.count * 8,
            kSecReturnPersistentRef: false
        ]
        var error: Unmanaged<CFError>?
        let secKey = SecKeyCreateWithData(priKeyECData as CFData, keyDict as CFDictionary, &error)
        return secKey
    }

    func publicKeyFromData(certificate: Data) -> SecKey? {
        var publicKey: SecKey?
        var trust: SecTrust?

        let cert = SecCertificateCreateWithData(kCFAllocatorDefault, certificate as CFData)!

        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(cert, policy, &trust)

        if status == errSecSuccess, let trust = trust {
            publicKey = SecTrustCopyPublicKey(trust)!
        }

        return publicKey
//        var error: Unmanaged<CFError>?
//        let data = SecKeyCopyExternalRepresentation(publicKey!, &error)! as Data
//
//        return data
    }
    
    func generateNonce(_ lenght: Int) throws -> Data {
        let nonce = NSMutableData(length: lenght)
        let result = SecRandomCopyBytes(kSecRandomDefault, nonce!.length, nonce!.mutableBytes)
        if result == errSecSuccess {
            return nonce! as Data
        } else {
            throw OPCUAError.generic("unsupported")
        }
    }
    
    func sign(dataToSign: [UInt8], privateKey: Data, clientCertificate: Data) throws -> Data {
        let key = privateKeyFromData(privateKey: privateKey)!
        
        let algorithm: SecKeyAlgorithm
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1:
            algorithm = .rsaSignatureMessagePKCS1v15SHA1
        case .rsaSha256:
            algorithm = .rsaSignatureMessagePKCS1v15SHA256
        default:
            algorithm = .rsaSignatureMessagePSSSHA256
        }

        guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
            throw OPCUAError.generic("unsupported sign algorithm")
        }
        
        let data = Data(dataToSign)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key,
                                                    algorithm,
                                                    data as CFData,
                                                    &error) as Data? else {
                                                        throw error!.takeRetainedValue() as Error
        }
        
        let publicKey = publicKeyFromData(certificate: clientCertificate)!

        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
            throw OPCUAError.generic("unsupported verify algorithm")
        }

        guard SecKeyVerifySignature(publicKey,
                                    algorithm,
                                    data as CFData,
                                    signature as CFData,
                                    &error) else {
                                        throw error!.takeRetainedValue() as Error
        }
        
        return signature
    }

    func crypt(dataToEncrypt: [UInt8], serverCertificate: Data) throws -> [UInt8] {
        let publicKey = publicKeyFromData(certificate: serverCertificate)!

        let algorithm: SecKeyAlgorithm
        switch asymmetricEncryptionAlgorithm {
        case .rsaOaepSha1:
            algorithm = .rsaEncryptionOAEPSHA1
        case .rsaOaepSha256:
            algorithm = .rsaEncryptionOAEPSHA256
        default:
            algorithm = .rsaEncryptionPKCS1
        }

        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            throw OPCUAError.generic("unsupported algorithm")
        }

        guard (dataToEncrypt.count < (SecKeyGetBlockSize(publicKey)-134)) else {
            throw OPCUAError.generic("data exceeds the allowed length")
        }

        let data = Data(UInt32(dataToEncrypt.count).bytes + dataToEncrypt)
        var error: Unmanaged<CFError>?
        guard let cipherText = SecKeyCreateEncryptedData(
            publicKey,
            algorithm,
            data as CFData,
            &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }

        return [UInt8](cipherText)
        
  
        /*
        /// https://github.com/airsidemobile/JOSESwift
         
        let encrypter = Encrypter(keyManagementAlgorithm: .RSA1_5, contentEncryptionAlgorithm: .A128CBCHS256, encryptionKey: publicKey)!
        let header = JWEHeader(keyManagementAlgorithm: .RSA1_5, contentEncryptionAlgorithm: .A128CBCHS256)

        let plainTextBlockSize: Int = getAsymmetricPlainTextBlockSize(
            publicKey: publicKey,
            algorithm: asymmetricEncryptionAlgorithm
        )
        let cipherTextBlockSize: Int = getAsymmetricCipherTextBlockSize(
            publicKey: publicKey,
            algorithm: asymmetricEncryptionAlgorithm
        )
        let blockCount: Int = (dataToEncrypt.count + plainTextBlockSize - 1) / plainTextBlockSize
        //let blockCount = ((dataToEncrypt.count + 4) / plainTextBlockSize) + 1
        
        let bufferAllocator = ByteBufferAllocator()
        var cipherTextNioBuffer = bufferAllocator.buffer(capacity: cipherTextBlockSize * blockCount)
        var plainTextNioBuffer = bufferAllocator.buffer(capacity: plainTextBlockSize * blockCount)
        plainTextNioBuffer.writeBytes(UInt32(dataToEncrypt.count).bytes)
        plainTextNioBuffer.writeBytes(dataToEncrypt)

        for blockNumber in 0..<blockCount {
            let position = blockNumber * plainTextBlockSize
            let limit = min(plainTextNioBuffer.readableBytes, (blockNumber + 1) * plainTextBlockSize)

            let bytes = Data(plainTextNioBuffer.getBytes(at: position, length: limit - position)!)
            let encryped = try encrypter.encrypt(header: header, payload: Payload(bytes))
            cipherTextNioBuffer.writeBytes(encryped.ciphertext)
//            let jwe = try JWE(header: header, payload: Payload(bytes), encrypter: encrypter)
//            cipherTextNioBuffer.writeBytes(jwe.ciphertext)
            
            print(bytes.count)
        }

        print(cipherTextNioBuffer.readableBytes)
        return cipherTextNioBuffer.getBytes(at: 0, length: cipherTextNioBuffer.readableBytes)!
        */
    }
    
    func getAsymmetricKeyLength(publicKey: SecKey) -> Int {
        return SecKeyGetBlockSize(publicKey) * 8
    }

    func getAsymmetricSignatureSize(publicKey: SecKey, algorithm: SecurityAlgorithm) -> Int {
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
            return (getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8
        default:
            return 0
        }
    }

    func getAsymmetricCipherTextBlockSize(publicKey: SecKey, algorithm: SecurityAlgorithm) -> Int {
        switch (algorithm) {
        case .rsa15, .rsaOaepSha1, .rsaOaepSha256:
            return (getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8
        default:
            return 1
        }
    }
    
    func getAsymmetricPlainTextBlockSize(publicKey: SecKey, algorithm: SecurityAlgorithm) -> Int {
        switch (algorithm) {
        case .rsa15:
            return ((getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8) - 11
        case .rsaOaepSha1:
            return ((getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8) - 136 //42
        case .rsaOaepSha256:
            return ((getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8) - 66
        default:
            return 1
        }
    }
    
    func getSymmetricBlockSize() -> Int {
        switch symmetricEncryptionAlgorithm {
        case .aes128, .aes256:
            return 16
        default:
            return 1
        }
    }

    func getSymmetricSignatureSize() -> Int {
        switch symmetricSignatureAlgorithm {
        case .hmacSha1:
                return 20
        case .hmacSha256:
                return 32
            default:
                return 0
        }
    }

    func getSymmetricSignatureKeySize() -> Int {
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
    
    func getSymmetricEncryptionKeySize() -> Int {
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
    
    func generateKeyPair(serverNonce: [UInt8], clientNonce: [UInt8]) -> SecurityKeys {
//        let privateAttributes = [String(kSecAttrIsPermanent): true,
//                                 String(kSecAttrApplicationTag): clientNonce,
//                                 String(kSecAttrAccessible): kSecAttrAccessibleAfterFirstUnlock] as [String : Any]
//        let publicAttributes = [String(kSecAttrIsPermanent): true,
//                                String(kSecAttrApplicationTag): serverNonce,
//                                String(kSecAttrAccessible): kSecAttrAccessibleAfterFirstUnlock] as [String : Any]
//
//        let pairAttributes = [String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
//                              String(kSecAttrKeySizeInBits): 2048,
//                              String(kSecPublicKeyAttrs): publicAttributes as [String : Any],
//                              String(kSecPrivateKeyAttrs): privateAttributes] as [String : Any]
//        var pubKey, privKey: SecKey?
//        _ = SecKeyGeneratePair(pairAttributes as CFDictionary, &pubKey, &privKey)
//        return (pubKey, privKey)
//    }
        
        let signatureKeySize = getSymmetricSignatureKeySize()
        let encryptionKeySize = getSymmetricEncryptionKeySize()
        let cipherTextBlockSize = getSymmetricBlockSize()

        assert(clientNonce.count > 0)
        assert(serverNonce.count > 0)

        let clientSignatureKey = keyDerivationAlgorithm == .pSha1
            ? createPSha1Key(serverNonce, clientNonce, 0, signatureKeySize)
            : createPSha256Key(serverNonce, clientNonce, 0, signatureKeySize)
    
        let clientEncryptionKey = keyDerivationAlgorithm == .pSha1
            ? createPSha1Key(serverNonce, clientNonce, signatureKeySize, encryptionKeySize)
            : createPSha256Key(serverNonce, clientNonce, signatureKeySize, encryptionKeySize)

        let clientInitializationVector = keyDerivationAlgorithm == .pSha1
            ? createPSha1Key(serverNonce, clientNonce, signatureKeySize + encryptionKeySize, cipherTextBlockSize)
            : createPSha256Key(serverNonce, clientNonce, signatureKeySize + encryptionKeySize, cipherTextBlockSize)

        let serverSignatureKey = keyDerivationAlgorithm == .pSha1
            ? createPSha1Key(clientNonce, serverNonce, 0, signatureKeySize)
            : createPSha256Key(clientNonce, serverNonce, 0, signatureKeySize)

        let serverEncryptionKey = keyDerivationAlgorithm == .pSha1
            ? createPSha1Key(clientNonce, serverNonce, signatureKeySize, encryptionKeySize)
            : createPSha256Key(clientNonce, serverNonce, signatureKeySize, encryptionKeySize)

        let serverInitializationVector = keyDerivationAlgorithm == .pSha1
            ? createPSha1Key(clientNonce, serverNonce, signatureKeySize + encryptionKeySize, cipherTextBlockSize)
            : createPSha256Key(clientNonce, serverNonce, signatureKeySize + encryptionKeySize, cipherTextBlockSize)

        return SecurityKeys(
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
    
    private func createPSha1Key(_ serverNonce: [UInt8], _ clientNonce: [UInt8], _ start: Int, _ end: Int) -> [UInt8] {
        let key = SymmetricKey(data: clientNonce)
        let hash = HMAC<Insecure.SHA1>.authenticationCode(for: serverNonce, using: key)
        let data = Data(hash)
        if HMAC<Insecure.SHA1>.isValidAuthenticationCode(data, authenticating: serverNonce, using: key) {
            print("Validated ✅")
        }
        return data[start..<end].map { $0 }
    }

    private func createPSha256Key(_ serverNonce: [UInt8], _ clientNonce: [UInt8], _ start: Int, _ end: Int) -> [UInt8] {
        let key = SymmetricKey(data: clientNonce)
        let hash = HMAC<SHA256>.authenticationCode(for: serverNonce, using: key)
        let data = Data(hash)
        if HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: serverNonce, using: key) {
            print("Validated ✅")
        }
        return data[start..<end].map { $0 }
    }
}

struct SecurityKeys {
    let clientKeys: SecretKeys
    let serverKeys: SecretKeys
}

struct SecretKeys {
    let signatureKey: [UInt8]
    let encryptionKey: [UInt8]
    let initializationVector: [UInt8]
}
