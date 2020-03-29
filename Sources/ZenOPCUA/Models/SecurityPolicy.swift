//
//  SecurityPolicy.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation
import NIO
#if os(Linux)
import Crypto
#else
import CryptoKit
#endif


public typealias KeyPair = (privateKey: SecKey, publicKey: SecKey)

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

class SecurityPolicy {
    var clientNonce: Data = Data()
    var clientCertificate: Data = Data()
    var clientPrivateKey: SecKey? = nil
    var clientPublicKey: SecKey? = nil
    var serverPublicKey: SecKey? = nil
    var remoteCertificateThumbprint: Data = Data()
    var localCertificateThumbprint: Data = Data()

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

    private static func generateNonce(_ lenght: Int) throws -> Data {
        let nonce = NSMutableData(length: lenght)
        let result = SecRandomCopyBytes(kSecRandomDefault, nonce!.length, nonce!.mutableBytes)
        if result == errSecSuccess {
            return nonce! as Data
        } else {
            throw OPCUAError.generic("unsupported")
        }
    }

    func loadClientCertificate(certificate: String? = nil, privateKey: String? = nil) {
        self.clientNonce = securityPolicyUri.securityPolicy != .none
            ? try! SecurityPolicy.generateNonce(32)
            : Data()
        
        if let certificateFile = certificate, let privateKeyFile = privateKey {
            if let certificateDate = try? Data(contentsOf: URL(fileURLWithPath: certificateFile)) {
                self.loadCertificateFromPem(data: certificateDate)
            }
                
            if let privateKeyData = try? Data(contentsOf: URL(fileURLWithPath: privateKeyFile)) {
                self.clientPrivateKey = privateKeyFromData(data: privateKeyData)
            }
        }
    }

    func loadServerCertificate() {
        serverPublicKey = publicKeyFromData(certificate: Data(OPCUAHandler.endpoint.serverCertificate))
        remoteCertificateThumbprint = Insecure.SHA1.hash(data: OPCUAHandler.endpoint.serverCertificate).data

        clientPublicKey = publicKeyFromData(certificate: clientCertificate)
        localCertificateThumbprint = Insecure.SHA1.hash(data: clientCertificate).data
    }
    
    func dataFromPEM(data: Data) -> Data {
//        let beginText = isCertificate ? "-----BEGIN CERTIFICATE-----" : "-----BEGIN RSA PRIVATE KEY-----"
//        let endText = isCertificate ? "-----END CERTIFICATE-----" : "-----END RSA PRIVATE KEY-----"
//        let begin = beginText.data(using: .utf8)!
//        let end = endText.data(using: .utf8)!
//
//        var index = 0
//        for i in 0..<data.count {
//            index = i + begin.count
//            if data[i..<index] == begin {
//                index += 1
//                break
//            }
//        }
//
//        let pemWithoutHeaderFooterNewlines = data[index..<(data.count - end.count - 2)]
//        return Data(base64Encoded: pemWithoutHeaderFooterNewlines, options: .ignoreUnknownCharacters)!
        
        let rows = String(data: data, encoding: .utf8)!.split(separator: "\n")
        let joined = rows[1...(rows.count - 2)].joined().data(using: .utf8)!
        return Data(base64Encoded: joined, options: .ignoreUnknownCharacters)!
    }
    
    func loadCertificateFromPem(data: Data) {
        let certData = dataFromPEM(data: data)
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)!
        clientCertificate = SecCertificateCopyData(certificate) as Data
    }

    func privateKeyFromData(data: Data, withPassword password: String = "") -> SecKey? {
        let priKeyECData = dataFromPEM(data: data)

        let keyDict: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: priKeyECData.count * 8,
            kSecImportExportPassphrase as CFString: password,
            kSecReturnPersistentRef: false
        ]
        var error: Unmanaged<CFError>?
        let secKey = SecKeyCreateWithData(priKeyECData as CFData, keyDict as CFDictionary, &error)
        return secKey
    }

    func publicKeyFromData(certificate: Data) -> SecKey? {
        var publicKey: SecKey?
        var trust: SecTrust?

        guard let cert = SecCertificateCreateWithData(kCFAllocatorDefault, certificate as CFData) else { return nil }

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
    
    func sign(dataToSign: [UInt8]) throws -> Data {
        let algorithm: SecKeyAlgorithm
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1:
            algorithm = .rsaSignatureMessagePKCS1v15SHA1
        case .rsaSha256:
            algorithm = .rsaSignatureMessagePKCS1v15SHA256
        default:
            algorithm = .rsaSignatureMessagePSSSHA256
        }

        guard SecKeyIsAlgorithmSupported(clientPrivateKey!, .sign, algorithm) else {
            throw OPCUAError.generic("unsupported sign algorithm")
        }
        
        let data = Data(dataToSign)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(clientPrivateKey!,
                                                    algorithm,
                                                    data as CFData,
                                                    &error) as Data? else {
                                                        throw error!.takeRetainedValue() as Error
        }

        guard SecKeyIsAlgorithmSupported(clientPublicKey!, .verify, algorithm) else {
            throw OPCUAError.generic("unsupported verify algorithm")
        }

        guard SecKeyVerifySignature(clientPublicKey!,
                                    algorithm,
                                    data as CFData,
                                    signature as CFData,
                                    &error) else {
                                        throw error!.takeRetainedValue() as Error
        }

        return signature
    }

    func crypt(dataToEncrypt: [UInt8]) throws -> [UInt8] {
        let algorithm: SecKeyAlgorithm
        switch asymmetricEncryptionAlgorithm {
        case .rsaOaepSha1:
            algorithm = .rsaEncryptionOAEPSHA1
        case .rsaOaepSha256:
            algorithm = .rsaEncryptionOAEPSHA256
        default:
            algorithm = .rsaEncryptionPKCS1
        }

        guard SecKeyIsAlgorithmSupported(serverPublicKey!, .encrypt, algorithm) else {
            throw OPCUAError.generic("unsupported algorithm")
        }

        guard (dataToEncrypt.count < (SecKeyGetBlockSize(serverPublicKey!)-134)) else {
            throw OPCUAError.generic("data exceeds the allowed length")
        }

        let data = Data(UInt32(dataToEncrypt.count).bytes + dataToEncrypt)
        var error: Unmanaged<CFError>?
        guard let cipherText = SecKeyCreateEncryptedData(
            serverPublicKey!,
            algorithm,
            data as CFData,
            &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }

        return [UInt8](cipherText)
    }
    
    
    func getSecurityHeaderSize() -> Int {
        return SECURE_MESSAGE_HEADER_SIZE +
            securityPolicyUri.count +
            clientCertificate.count +
            remoteCertificateThumbprint.count
    }
    
    func isAsymmetricSigningEnabled() -> Bool {
        return OPCUAHandler.messageSecurityMode != .none
            && !OPCUAHandler.isAcknowledgeSecure
            && clientCertificate.count > 0
    }
    
    func isAsymmetricEncryptionEnabled() -> Bool {
        return OPCUAHandler.messageSecurityMode != .none
            && !OPCUAHandler.isAcknowledgeSecure
            && clientCertificate.count > 0
            && OPCUAHandler.endpoint.serverCertificate.count > 0
    }
    
    func getAsymmetricKeyLength(publicKey: SecKey) -> Int {
        return SecKeyGetBlockSize(publicKey) * 8
    }

    func getAsymmetricSignatureSize() -> Int {
        guard let clientPublicKey = clientPublicKey else { return 0 }
        
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
            return (getAsymmetricKeyLength(publicKey: clientPublicKey) + 7) / 8
        default:
            return 0
        }
    }

    func getAsymmetricCipherTextBlockSize() -> Int {
        guard let serverPublicKey = serverPublicKey else { return 1 }

        switch (asymmetricEncryptionAlgorithm) {
        case .rsa15, .rsaOaepSha1, .rsaOaepSha256:
            return (getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8
        default:
            return 1
        }
    }
    
    func getAsymmetricPlainTextBlockSize() -> Int {
        guard let serverPublicKey = serverPublicKey else { return 1 }

        switch (asymmetricEncryptionAlgorithm) {
//        case .rsa15:
//            return ((getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8) - 11
//        case .rsaOaepSha1:
//            return ((getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8) - 136 //42
//        case .rsaOaepSha256:
//            return ((getAsymmetricKeyLength(publicKey: publicKey) + 7) / 8) - 66
        case .rsa15, .rsaOaepSha1, .rsaOaepSha256:
            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 136 //42
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
    
    func generateKeyPair(ofSize bits: UInt) throws -> KeyPair? {
        let pubKeyAttrs = [ kSecAttrIsPermanent as String: true ]
        let privKeyAttrs = [ kSecAttrIsPermanent as String: true ]
        let params: NSDictionary = [ kSecAttrKeyType as String : kSecAttrKeyTypeRSA as String,
                       kSecAttrKeySizeInBits as String : bits,
                       kSecPublicKeyAttrs as String : pubKeyAttrs,
                       kSecPrivateKeyAttrs as String : privKeyAttrs ]
        var pubKey: SecKey?
        var privKey: SecKey?
        let status = SecKeyGeneratePair(params, &pubKey, &privKey)
        switch status {
        case noErr:
            return (privKey!, pubKey!)
        default:
            return nil
        }
    }

    func generateSecurityKeys(serverNonce: [UInt8], clientNonce: [UInt8]) -> SecurityKeys {
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
