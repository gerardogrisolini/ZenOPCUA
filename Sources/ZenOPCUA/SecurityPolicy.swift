//
//  SecurityPolicy.swift
//
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation
import NIO

// Concurrency: confined to the channel's EventLoop via OPCUAConnectionState.
class SecurityPolicy: @unchecked Sendable {

    weak var connectionState: OPCUAConnectionState?
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
        // Reset hasRemoteCertificate when creating new SecurityPolicy instance
        connectionState?.hasRemoteCertificate = false
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
            // OPC UA Basic256Sha256 uses RSA-OAEP with SHA-1 for asymmetric encryption.
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha1
            self.asymmetricKeyWrapAlgorithm = .kwRsaOaep
            self.keyDerivationAlgorithm = .pSha256
            self.certificateSignatureAlgorithm = .sha256

        case .aes128Sha256RsaOaep:
            self.symmetricSignatureAlgorithm = .hmacSha256
            self.symmetricEncryptionAlgorithm = .aes256
            self.asymmetricSignatureAlgorithm = .rsaSha256
            self.asymmetricEncryptionAlgorithm = .rsaOaepSha256
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

    func loadLocalCertificate(certificate: String? = nil, privateKey: String? = nil) {
        guard let certificateFile = certificate, let privateKeyFile = privateKey else { return }

        do {
            let certificateData = try Data(contentsOf: URL(fileURLWithPath: certificateFile))
            
            // Convert PEM to DER if needed
            if let pemString = String(data: certificateData, encoding: .utf8),
               pemString.contains("-----BEGIN CERTIFICATE-----") {
                let lines = pemString.components(separatedBy: .newlines)
                let base64String = lines
                    .filter { !$0.contains("-----") && !$0.isEmpty }
                    .joined()
                
                if let derData = Data(base64Encoded: base64String) {
                    localCertificate = derData
                    localCertificateThumbprint = RSACrypto.sha1(data: derData)
                } else {
                    print("Failed to decode PEM certificate")
                }
            } else {
                // Already in DER format
                localCertificate = certificateData
                localCertificateThumbprint = RSACrypto.sha1(data: certificateData)
            }
        } catch {
            print("localCertificateAndPublicKey: \(error)")
        }

        do {
            localPrivateKey = try Data(contentsOf: URL(fileURLWithPath: privateKeyFile))
        } catch {
            print("localPrivateKey: \(error)")
        }
        
        // Generate client nonce for secure channel
        if localCertificate.count > 0 {
            let nonceLength = 32 // Standard nonce length for Basic256Sha256
            clientNonce = [UInt8](RSACrypto.generateNonce(nonceLength))
        }
    }

    func loadRemoteCertificate(data: [UInt8]) {
        remoteCertificate.append(contentsOf: data)
        remoteCertificateThumbprint = RSACrypto.sha1(data: remoteCertificate)
        connectionState?.hasRemoteCertificate = true
    }
    
    var securityHeaderSize: Int {
        let policyUri = isEncryptionEnabled ? securityPolicyUri.count : SecurityPolicies.none.uri.count
        // Include the 4-byte length prefixes for policyUri (as string), certificate, and thumbprint
        // This represents the security header part ONLY (without SECURE_MESSAGE_HEADER_SIZE which is added separately)
        // When remoteCertificate is empty (first connection), placeholders are used instead of actual cert/thumbprint
        if remoteCertificate.count == 0 {
            // Placeholders: policyUri + UInt32.max + UInt32.max
            return 4 + policyUri + 4 + 4  // policyUri + 2 placeholders (4 bytes each)
        } else {
            // For OPN messages: thumbprint is NULL when not encrypted.
            // Include it when encrypted or when compatibility override is enabled.
            let isSignAndEncrypt = (connectionState?.messageSecurityMode ?? .none) == .signAndEncrypt
            let includeThumbprintOverride = connectionState?.includeServerThumbprintInOpn ?? false
            let thumbprintLength = (isSignAndEncrypt || includeThumbprintOverride
                || securityPolicyUri.securityPolicy == .aes256Sha256RsaPss)
                ? remoteCertificateThumbprint.count
                : 0
            return 4 + policyUri +  // policyUri length prefix + string
                4 + localCertificate.count +  // certificate length prefix + data
                4 + thumbprintLength  // receiverCertificateThumbprint length prefix + data (if present)
        }
    }

    var securityRemoteHeaderSize: Int {
        // Include the 4-byte length prefixes for policyUri (as string), certificate, and thumbprint
        return 4 + securityPolicyUri.count +  // policyUri length prefix + string
            4 + remoteCertificate.count +  // certificate length prefix + data
            4 + localCertificateThumbprint.count  // thumbprint length prefix + data
    }
        
    var remoteAsymmetricSignatureSize: Int {
        let keySize = RSACrypto.keySizeBytes(from: remoteCertificate)
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
            return keySize
        default:
            return 0
        }
    }

    var asymmetricSignatureSize: Int {
        let keySize = RSACrypto.keySizeBytes(from: localCertificate)
        switch asymmetricSignatureAlgorithm {
        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
            return keySize
        default:
            return 0
        }
    }

    var asymmetricCipherTextBlockSize: Int {
        // For asymmetric encryption, cipherTextBlockSize is always the key size (modulus size)
        let keySize = RSACrypto.keySizeBytes(from: remoteCertificate)
        return max(keySize, 1)
    }
    
    var asymmetricPlainTextBlockSize: Int {
        let keySize = RSACrypto.keySizeBytes(from: remoteCertificate)
        let safeKeySize = max(keySize, 1)
        switch asymmetricEncryptionAlgorithm {
        case .rsa15:
            return safeKeySize - 11
        case .rsaOaepSha1:
            return safeKeySize - 42
        case .rsaOaepSha256:
            return safeKeySize - 66
        default:
            return 1
        }
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
        return (connectionState?.messageSecurityMode ?? .none) != .none && localCertificate.count > 0
    }
    
    var isSymmetricSigningEnabled: Bool {
        return localCertificate.count > 0 && (connectionState?.messageSecurityMode ?? .none) != .none
            && ((connectionState?.messageSecurityMode ?? .none) == .sign || (connectionState?.messageSecurityMode ?? .none) == .signAndEncrypt)
    }
    
    var isAsymmetricEncryptionEnabled: Bool {
        return (connectionState?.messageSecurityMode ?? .none) != .none
            && localCertificate.count > 0
            && remoteCertificate.count > 0
    }

   var isSymmetricEncryptionEnabled: Bool {
        return remoteCertificate.count > 0 && (connectionState?.messageSecurityMode ?? .none) != .none
            && (connectionState?.messageSecurityMode ?? .none) == .signAndEncrypt
    }

    var isSigningEnabled: Bool { (connectionState?.messageSecurityMode ?? .none) != .none && localCertificate.count > 0 }
    var isEncryptionEnabled: Bool { 
        (connectionState?.messageSecurityMode ?? .none) == .signAndEncrypt 
            && localCertificate.count > 0 
            && remoteCertificate.count > 0  // Need remote cert to encrypt
    }
    var isAsymmetric: Bool { RSACrypto.getSecurityKeys() == nil }
    
    /* Common */

    func sign(data: Data) throws -> Data {
        try isAsymmetric ? signAsymmetric(data: data) : signSymmetric(data: data)
    }

    func signVerify(signature: Data, data: Data) -> Bool {
        isAsymmetric ? signVerifyAsymmetric(signature: signature, data: data) : signVerifySymmetric(signature: signature, data: data)
    }
    
    /* Asymmetric */

    func signAsymmetric(data: Data) throws -> Data {
        let privateKey = try RSACrypto.withLocalKeys { keys in
            if let cached = keys.signingPrivateKey {
                return cached
            }
            let (_, signingKey) = try RSACrypto.loadPrivateKey(from: localPrivateKey)
            keys.signingPrivateKey = signingKey
            return signingKey
        }

        switch asymmetricSignatureAlgorithm {
        case .rsaSha1:
            return try RSACrypto.signPKCS1v15_SHA1(data: data, privateKey: privateKey)
        case .rsaSha256:
            return try RSACrypto.signPKCS1v15_SHA256(data: data, privateKey: privateKey)
        case .rsaSha256Pss:
            return try RSACrypto.signPSS_SHA256(data: data, privateKey: privateKey)
        default:
            throw OPCUAError.generic("Unsupported signature algorithm: \(asymmetricSignatureAlgorithm)")
        }
    }

    
    func signVerifyAsymmetric(signature: Data, data: Data) -> Bool {
        do {
            let publicKey = try RSACrypto.withLocalKeys { keys in
                if let cached = keys.signingPublicKey {
                    return cached
                }
                let loaded = try RSACrypto.loadSigningPublicKey(from: localCertificate)
                keys.signingPublicKey = loaded
                return loaded
            }

            switch asymmetricSignatureAlgorithm {
            case .rsaSha1:
                return RSACrypto.verifyPKCS1v15_SHA1(signature: signature, data: data, publicKey: publicKey)
            case .rsaSha256:
                return RSACrypto.verifyPKCS1v15_SHA256(signature: signature, data: data, publicKey: publicKey)
            case .rsaSha256Pss:
                return RSACrypto.verifyPSS_SHA256(signature: signature, data: data, publicKey: publicKey)
            default:
                return false
            }
        } catch {
            return false
        }
    }
    
    func cryptAsymmetric(data: [UInt8]) throws -> [UInt8] {
        let publicKey = try RSACrypto.withRemoteKeys { keys in
            if let cached = keys.publicKey {
                return cached
            }
            let loaded = try RSACrypto.loadPublicKey(from: remoteCertificate)
            keys.publicKey = loaded
            return loaded
        }

        switch asymmetricEncryptionAlgorithm {
        case .rsaOaepSha256:
            return try RSACrypto.encryptOAEP_SHA256(plaintext: data, publicKey: publicKey)
        case .rsaOaepSha1:
            return try RSACrypto.encryptOAEP_SHA1(plaintext: data, publicKey: publicKey)
        case .rsa15:
            return try RSACrypto.encryptPKCS1(plaintext: data, publicKey: publicKey)
        default:
            throw OPCUAError.generic("Unsupported encryption algorithm: \(asymmetricEncryptionAlgorithm)")
        }
    }

        
    func decryptAsymmetric(data: [UInt8]) throws -> [UInt8] {
        let privateKey = try RSACrypto.withLocalKeys { keys in
            if let cached = keys.privateKey {
                return cached
            }
            let (encryptionKey, _) = try RSACrypto.loadPrivateKey(from: localPrivateKey)
            keys.privateKey = encryptionKey
            return encryptionKey
        }

        switch asymmetricEncryptionAlgorithm {
        case .rsaOaepSha256:
            return try RSACrypto.decryptOAEP_SHA256(ciphertext: data, privateKey: privateKey)
        case .rsaOaepSha1:
            return try RSACrypto.decryptOAEP_SHA1(ciphertext: data, privateKey: privateKey)
        case .rsa15:
            return try RSACrypto.decryptPKCS1(ciphertext: data, privateKey: privateKey)
        default:
            throw OPCUAError.generic("Unsupported encryption algorithm: \(asymmetricEncryptionAlgorithm)")
        }
    }
    

    /* Symmetric */

    func cryptSymmetric(data: [UInt8]) throws -> [UInt8] {
        // Client encrypts outgoing messages with clientKeys
        guard let keys = RSACrypto.getSecurityKeys() else {
            throw OPCUAError.generic("Missing symmetric keys")
        }
        let key = keys.clientKeys.encryptionKey
        let iv = keys.clientKeys.initializationVector

        do {
            // Use noPadding because OPC UA handles padding itself according to the specification
            return try RSACrypto.aesCBCEncrypt(plaintext: data, key: key, iv: iv, noPadding: true)
        } catch {
            throw OPCUAError.generic("AES-CBC encryption failed: \(error.localizedDescription)")
        }
    }

    func decryptSymmetric(data: [UInt8]) throws -> [UInt8] {
        guard let keys = RSACrypto.getSecurityKeys() else {
            throw OPCUAError.generic("Missing symmetric keys")
        }
        let key = keys.serverKeys.encryptionKey
        let iv = keys.serverKeys.initializationVector

        do {
            // Use noPadding because OPC UA handles padding itself according to the specification
            return try RSACrypto.aesCBCDecrypt(ciphertext: data, key: key, iv: iv, noPadding: true)
        } catch {
            throw OPCUAError.generic("AES-CBC decryption failed: \(error.localizedDescription)")
        }
    }
    
    func signSymmetric(data: Data) -> Data {
        guard let keys = RSACrypto.getSecurityKeys() else {
            return Data()
        }
        let key = keys.clientKeys.signatureKey

        switch symmetricSignatureAlgorithm {
        case .hmacSha1:
            return RSACrypto.hmacSha1(key: key, data: data)
        case .hmacSha256:
            return RSACrypto.hmacSha256(key: key, data: data)
        default:
            return Data()
        }
    }

    func signVerifySymmetric(signature: Data, data: Data) -> Bool {
        guard let keys = RSACrypto.getSecurityKeys() else {
            return false
        }
        let key = keys.serverKeys.signatureKey

        switch symmetricSignatureAlgorithm {
        case .hmacSha1:
            return RSACrypto.hmacSha1(key: key, data: data) == signature
        case .hmacSha256:
            return RSACrypto.hmacSha256(key: key, data: data) == signature
        default:
            return false
        }
    }

    func signVerifySymmetricLocal(signature: Data, data: Data) -> Bool {
        guard let keys = RSACrypto.getSecurityKeys() else {
            return false
        }
        let key = keys.clientKeys.signatureKey

        switch symmetricSignatureAlgorithm {
        case .hmacSha1:
            return RSACrypto.hmacSha1(key: key, data: data) == signature
        case .hmacSha256:
            return RSACrypto.hmacSha256(key: key, data: data) == signature
        default:
            return false
        }
    }
    
}
