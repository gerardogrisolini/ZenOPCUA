//
//  SecurityPolicy.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation
import NIO
import CryptorRSA
#if os(Linux)
import Crypto
#else
import CryptoKit
#endif


public typealias KeyPair = (privateKey: CryptorRSA.PrivateKey, publicKey: CryptorRSA.PublicKey)

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
    var clientPrivateKey: CryptorRSA.PrivateKey!
    var clientPublicKey: CryptorRSA.PublicKey!
    var serverPublicKey: CryptorRSA.PublicKey!
    
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

    private static func generateNonce(_ lenght: Int) -> Data {
        return Data(repeating: UInt8.random(in: 0...255), count: lenght)
    }

    func loadClientCertificate(certificate: String? = nil, privateKey: String? = nil) {
        self.clientNonce = securityPolicyUri.securityPolicy != .none
            ? SecurityPolicy.generateNonce(32)
            : Data()

        if let certificateFile = certificate, let privateKeyFile = privateKey {
            do {
                let certificateDate = try Data(contentsOf: URL(fileURLWithPath: certificateFile))
                //clientCertificate = try CryptorRSA.stripX509CertificateHeader(for: certificateDate)
                clientCertificate = dataFromPEM(data: certificateDate)
                localCertificateThumbprint = Data(Insecure.SHA1.hash(data: clientCertificate))
                clientPublicKey = try CryptorRSA.createPublicKey(extractingFrom: certificateDate)

                let privateKeyData = try Data(contentsOf: URL(fileURLWithPath: privateKeyFile))
                self.clientPrivateKey = try CryptorRSA.createPrivateKey(with: privateKeyData)
            } catch {
                print("loadClientCertificate: \(error)")
            }
        }
    }

    func loadServerCertificate() {
        do {
            let data = Data(OPCUAHandler.endpoint.serverCertificate)
             remoteCertificateThumbprint = Data(Insecure.SHA1.hash(data: data))
//            let pemString = CryptorRSA.convertDerToPem(from: data, type: .publicType)
//            let pem = pemString.data(using: .utf8)!
//            serverPublicKey = try CryptorRSA.createPublicKey(with: pem)
            print("serverCertificate: \(data.count)")
            serverPublicKey = try CryptorRSA.createPublicKey(extractingFrom: data.)
        } catch {
            print("loadServerCertificate: \(error)")
        }
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
    }
    
    fileprivate func dataFromPEM(data: Data) -> Data {
        let rows = String(data: data, encoding: .ascii)!.split(separator: "\n")
        let joined = rows[1...(rows.count - 2)].joined().data(using: .ascii)!
        return Data(base64Encoded: joined, options: .ignoreUnknownCharacters)!
    }
    
    func sign(dataToSign: Data) throws -> Data {
        let algorithm: Data.Algorithm
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1:
            algorithm = .sha1
        case .rsaSha256:
            algorithm = .sha256
        default:
            algorithm = .gcm
        }

        let myPlaintext = CryptorRSA.createPlaintext(with: dataToSign)
        let signedData = try myPlaintext.signed(with: clientPrivateKey!, algorithm: algorithm)
        if !(try myPlaintext.verify(with: clientPublicKey!, signature: signedData!, algorithm: algorithm)) {
            throw OPCUAError.generic("Signature Verification Failed")
        }

        return signedData!.data
    }

    func crypt(dataToEncrypt: [UInt8]) throws -> [UInt8] {
        let algorithm: Data.Algorithm
        switch asymmetricEncryptionAlgorithm {
        case .rsaOaepSha1:
            algorithm = .sha256
        case .rsaOaepSha256:
            algorithm = .sha256
        default:
            algorithm = .gcm
        }
        
        #if os(macOS)
        guard dataToEncrypt.count < 256-134 else {
            throw OPCUAError.generic("data exceeds the allowed length")
        }
        #endif
        
        let myPlaintext = CryptorRSA.createPlaintext(with: Data(dataToEncrypt))
        let encryptedData = try myPlaintext.encrypted(with: serverPublicKey!, algorithm: algorithm)
        return [UInt8](encryptedData!.data)
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
    
    func getAsymmetricKeyLength(publicKey: CryptorRSA.PublicKey) -> Int {
        return 256 * 8 //SecKeyGetBlockSize(publicKey) * 8
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
        #if os(Linux)
        case .rsa15:
            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 11
        case .rsaOaepSha1:
            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 42
        case .rsaOaepSha256:
            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 66
        #else
        case .rsa15, .rsaOaepSha1, .rsaOaepSha256:
            return ((getAsymmetricKeyLength(publicKey: serverPublicKey) + 7) / 8) - 136
        #endif
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
    
    func generateKeyPair(ofSize bits: CryptorRSA.RSAKey.KeySize) throws -> KeyPair {
        return try CryptorRSA.makeKeyPair(bits)
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
