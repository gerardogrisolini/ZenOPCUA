//
//  RSACrypto.swift
//  ZenOPCUA
//
//  RSA encryption/decryption using Swift Crypto (BoringSSL-based)
//  for better compatibility with OPC UA servers using BouncyCastle
//

import Foundation
import Crypto
import _CryptoExtras
import X509
import NIOConcurrencyHelpers

/// Encryption/Decryption using Swift Crypto (BoringSSL backend)
enum RSACrypto {
    
    // MARK: - Security Keys
    
    struct SecurityKeys {
        let clientKeys: SecretKeys
        let serverKeys: SecretKeys
    }
    
    struct SecretKeys {
        let signatureKey: Data
        let encryptionKey: Data
        let initializationVector: Data
    }
    
    // MARK: - Cached Keys
    
    struct KeyPair {
        var publicKey: _RSA.Encryption.PublicKey?
        var privateKey: _RSA.Encryption.PrivateKey?
        var signingPrivateKey: _RSA.Signing.PrivateKey?
        var signingPublicKey: _RSA.Signing.PublicKey?
    }
    
    private struct LockedBox<T>: @unchecked Sendable {
        let box: NIOLockedValueBox<T>
    }

    private static let localKeysBox = LockedBox(box: NIOLockedValueBox(KeyPair()))
    private static let remoteKeysBox = LockedBox(box: NIOLockedValueBox(KeyPair()))
    private static let securityKeysBox = LockedBox(box: NIOLockedValueBox<SecurityKeys?>(nil))

    static func withLocalKeys<T>(_ body: (inout KeyPair) throws -> T) rethrows -> T {
        try localKeysBox.box.withLockedValue { keys in
            try body(&keys)
        }
    }

    static func withRemoteKeys<T>(_ body: (inout KeyPair) throws -> T) rethrows -> T {
        try remoteKeysBox.box.withLockedValue { keys in
            try body(&keys)
        }
    }

    static func getSecurityKeys() -> SecurityKeys? {
        securityKeysBox.box.withLockedValue { $0 }
    }

    static func setSecurityKeys(_ keys: SecurityKeys?) {
        securityKeysBox.box.withLockedValue { $0 = keys }
    }
    
    // MARK: - RSA Key Management
    
    /// Extract RSA public key from X.509 DER certificate
    static func loadPublicKey(from certificateData: Data) throws -> _RSA.Encryption.PublicKey {
        let keyData = try subjectPublicKeyInfo(from: certificateData)
        return try _RSA.Encryption.PublicKey(derRepresentation: keyData)
    }
    
    /// Extract RSA public signing key from X.509 DER certificate
    static func loadSigningPublicKey(from certificateData: Data) throws -> _RSA.Signing.PublicKey {
        let keyData = try subjectPublicKeyInfo(from: certificateData)
        return try _RSA.Signing.PublicKey(derRepresentation: keyData)
    }
    
    /// Load RSA private key from PEM data
    static func loadPrivateKey(from pemData: Data) throws -> (_RSA.Encryption.PrivateKey, _RSA.Signing.PrivateKey) {
        // Convert Data to String for PEM parsing
        guard let pemString = String(data: pemData, encoding: .utf8) else {
            throw OPCUAError.generic("Invalid PEM data encoding")
        }

        let encryptionKey = try _RSA.Encryption.PrivateKey(pemRepresentation: pemString)
        let signingKey = try _RSA.Signing.PrivateKey(pemRepresentation: pemString)
        return (encryptionKey, signingKey)
    }
    
    private static func subjectPublicKeyInfo(from certificateData: Data) throws -> Data {
        let cert = try Certificate(derEncoded: Array(certificateData))
        return Data(cert.publicKey.subjectPublicKeyInfoBytes)
    }

    static func keySizeBytes(from certificateData: Data) -> Int {
        do {
            let spki = try subjectPublicKeyInfo(from: certificateData)
            let pubKey = try _RSA.Signing.PublicKey(derRepresentation: spki)
            return (pubKey.keySizeInBits + 7) / 8
        } catch {
            return 0
        }
    }
    
    // MARK: - Symmetric Crypto (AES/HMAC/SHA)
    
    static func sha1(data: Data) -> Data {
        Data(Insecure.SHA1.hash(data: data))
    }
    
    static func sha256(data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
    
    static func hmacSha1(key: Data, data: Data) -> Data {
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(mac)
    }
    
    static func hmacSha256(key: Data, data: Data) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(mac)
    }
    
    static func aesCBCEncrypt(plaintext: [UInt8], key: Data, iv: Data, noPadding: Bool = true) throws -> [UInt8] {
        let symmetricKey = SymmetricKey(data: key)
        let ivBytes = [UInt8](iv)
        let iv = try AES._CBC.IV(ivBytes: ivBytes)
        let ciphertext = try AES._CBC.encrypt(plaintext, using: symmetricKey, iv: iv, noPadding: noPadding)
        return [UInt8](ciphertext)
    }
    
    static func aesCBCDecrypt(ciphertext: [UInt8], key: Data, iv: Data, noPadding: Bool = true) throws -> [UInt8] {
        let symmetricKey = SymmetricKey(data: key)
        let ivBytes = [UInt8](iv)
        let iv = try AES._CBC.IV(ivBytes: ivBytes)
        let plaintext = try AES._CBC.decrypt(ciphertext, using: symmetricKey, iv: iv, noPadding: noPadding)
        return [UInt8](plaintext)
    }
    
    static func createPShaKey(
        secret: [UInt8],
        seed: [UInt8],
        offset: Int,
        length: Int,
        algorithm: SecurityAlgorithm
    ) -> Data {
        var required = offset + length
        var out = Data()
        var a = Data(seed)
        
        let secretData = Data(secret)
        if algorithm == .pSha1 {
            while required > 0 {
                let mac1 = hmacSha1(key: secretData, data: a)
                a = mac1
                var combined = Data(a)
                combined.append(contentsOf: seed)
                let mac2 = hmacSha1(key: secretData, data: combined)
                let toCopy = min(required, mac2.count)
                out.append(mac2.prefix(toCopy))
                required -= toCopy
            }
        } else {
            while required > 0 {
                let mac1 = hmacSha256(key: secretData, data: a)
                a = mac1
                var combined = Data(a)
                combined.append(contentsOf: seed)
                let mac2 = hmacSha256(key: secretData, data: combined)
                let toCopy = min(required, mac2.count)
                out.append(mac2.prefix(toCopy))
                required -= toCopy
            }
        }
        
        if out.count < offset + length {
            return Data()
        }
        return out.subdata(in: offset..<(offset + length))
    }
    
    static func generateSecurityKeys(
        serverNonce: [UInt8],
        clientNonce: [UInt8],
        symmetricSignatureKeySize: Int,
        symmetricEncryptionKeySize: Int,
        symmetricBlockSize: Int,
        keyDerivationAlgorithm: SecurityAlgorithm
    ) {
        let clientSignatureKey = createPShaKey(
            secret: serverNonce,
            seed: clientNonce,
            offset: 0,
            length: symmetricSignatureKeySize,
            algorithm: keyDerivationAlgorithm
        )
        let clientEncryptionKey = createPShaKey(
            secret: serverNonce,
            seed: clientNonce,
            offset: symmetricSignatureKeySize,
            length: symmetricEncryptionKeySize,
            algorithm: keyDerivationAlgorithm
        )
        let clientInitializationVector = createPShaKey(
            secret: serverNonce,
            seed: clientNonce,
            offset: symmetricSignatureKeySize + symmetricEncryptionKeySize,
            length: symmetricBlockSize,
            algorithm: keyDerivationAlgorithm
        )
        let serverSignatureKey = createPShaKey(
            secret: clientNonce,
            seed: serverNonce,
            offset: 0,
            length: symmetricSignatureKeySize,
            algorithm: keyDerivationAlgorithm
        )
        let serverEncryptionKey = createPShaKey(
            secret: clientNonce,
            seed: serverNonce,
            offset: symmetricSignatureKeySize,
            length: symmetricEncryptionKeySize,
            algorithm: keyDerivationAlgorithm
        )
        let serverInitializationVector = createPShaKey(
            secret: clientNonce,
            seed: serverNonce,
            offset: symmetricSignatureKeySize + symmetricEncryptionKeySize,
            length: symmetricBlockSize,
            algorithm: keyDerivationAlgorithm
        )
        
        setSecurityKeys(
            SecurityKeys(
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
        )
    }
    
    // MARK: - RSA-OAEP Encryption (OPC UA Compatible)
    
    /// Encrypt data using RSA-OAEP-SHA256 (Basic256Sha256)
    static func encryptOAEP_SHA256(plaintext: [UInt8], publicKey: _RSA.Encryption.PublicKey) throws -> [UInt8] {
        // Swift Crypto _CryptoExtras provides RSA encryption with OAEP padding
        // The padding parameter uses BoringSSL's RSA_OAEP implementation
        let ciphertext = try publicKey.encrypt(
            Data(plaintext),
            padding: .PKCS1_OAEP
        )
        return [UInt8](ciphertext)
    }

    /// Decrypt data using RSA-OAEP-SHA256
    static func decryptOAEP_SHA256(ciphertext: [UInt8], privateKey: _RSA.Encryption.PrivateKey) throws -> [UInt8] {
        let plaintext = try privateKey.decrypt(
            Data(ciphertext),
            padding: .PKCS1_OAEP
        )
        return [UInt8](plaintext)
    }

    /// Encrypt data using RSA-OAEP-SHA1
    static func encryptOAEP_SHA1(plaintext: [UInt8], publicKey: _RSA.Encryption.PublicKey) throws -> [UInt8] {
        let ciphertext = try publicKey.encrypt(
            Data(plaintext),
            padding: .PKCS1_OAEP
        )
        return [UInt8](ciphertext)
    }

    /// Decrypt data using RSA-OAEP-SHA1
    static func decryptOAEP_SHA1(ciphertext: [UInt8], privateKey: _RSA.Encryption.PrivateKey) throws -> [UInt8] {
        let plaintext = try privateKey.decrypt(
            Data(ciphertext),
            padding: .PKCS1_OAEP
        )
        return [UInt8](plaintext)
    }

    /// Encrypt data using RSAES-PKCS1-v1_5
    static func encryptPKCS1(plaintext: [UInt8], publicKey: _RSA.Encryption.PublicKey) throws -> [UInt8] {
        let ciphertext = try publicKey.encrypt(
            Data(plaintext),
            padding: .PKCS1_OAEP
        )
        return [UInt8](ciphertext)
    }

    /// Decrypt data using RSAES-PKCS1-v1_5
    static func decryptPKCS1(ciphertext: [UInt8], privateKey: _RSA.Encryption.PrivateKey) throws -> [UInt8] {
        let plaintext = try privateKey.decrypt(
            Data(ciphertext),
            padding: .PKCS1_OAEP
        )
        return [UInt8](plaintext)
    }
    
    // MARK: - RSA Signatures
    
    /// Sign data using RSA-PKCS1v15-SHA256 (OPC UA Basic256Sha256)
    static func signPKCS1v15_SHA256(data: Data, privateKey: _RSA.Signing.PrivateKey) throws -> Data {
        // IMPORTANT: For RSA-PKCS1v1.5 with SHA-256, the signature operation is:
        // 1. Hash the data with SHA-256
        // 2. Create DigestInfo structure: DigestInfo = AlgorithmIdentifier || Digest
        // 3. Apply PKCS#1 v1.5 padding to DigestInfo
        // 4. Sign with RSA private key
        //
        // Swift Crypto's signature(for:padding:) should handle steps 2-4 automatically
        // when given a SHA256.Digest

        // Hash the data
        let digest = SHA256.hash(data: data)

        // Sign the digest using PKCS1v1.5 padding
        let signature = try privateKey.signature(for: digest, padding: .insecurePKCS1v1_5)

        return Data(signature.rawRepresentation)
    }
    
    /// Verify signature using RSA-PKCS1v15-SHA256
    static func verifyPKCS1v15_SHA256(signature: Data, data: Data, publicKey: _RSA.Signing.PublicKey) -> Bool {
        let digest = SHA256.hash(data: data)
        let sig = _RSA.Signing.RSASignature(rawRepresentation: signature)
        return publicKey.isValidSignature(sig, for: digest, padding: .insecurePKCS1v1_5)
    }

    /// Sign data using RSA-PKCS1v15-SHA1 (OPC UA Basic128Rsa15 / Basic256)
    static func signPKCS1v15_SHA1(data: Data, privateKey: _RSA.Signing.PrivateKey) throws -> Data {
        let digest = Insecure.SHA1.hash(data: data)
        let signature = try privateKey.signature(for: digest, padding: .insecurePKCS1v1_5)
        return Data(signature.rawRepresentation)
    }

    /// Verify signature using RSA-PKCS1v15-SHA1
    static func verifyPKCS1v15_SHA1(signature: Data, data: Data, publicKey: _RSA.Signing.PublicKey) -> Bool {
        let digest = Insecure.SHA1.hash(data: data)
        let sig = _RSA.Signing.RSASignature(rawRepresentation: signature)
        return publicKey.isValidSignature(sig, for: digest, padding: .insecurePKCS1v1_5)
    }

    /// Sign data using RSA-PSS-SHA256 (OPC UA Aes256_Sha256_RsaPss)
    static func signPSS_SHA256(data: Data, privateKey: _RSA.Signing.PrivateKey) throws -> Data {
        let digest = SHA256.hash(data: data)
        let signature = try privateKey.signature(for: digest, padding: .PSS)
        return Data(signature.rawRepresentation)
    }

    /// Verify signature using RSA-PSS-SHA256
    static func verifyPSS_SHA256(signature: Data, data: Data, publicKey: _RSA.Signing.PublicKey) -> Bool {
        let digest = SHA256.hash(data: data)
        let sig = _RSA.Signing.RSASignature(rawRepresentation: signature)
        return publicKey.isValidSignature(sig, for: digest, padding: .PSS)
    }
    
    static func generateNonce(_ length: Int) -> Data {
        var rng = SystemRandomNumberGenerator()
        return Data((0..<length).map { _ in UInt8.random(in: 0...255, using: &rng) })
    }

    static func thumbprintHex(from certificateData: Data) -> String {
        var derData = certificateData
        if let pemString = String(data: certificateData, encoding: .utf8),
           pemString.contains("-----BEGIN CERTIFICATE-----") {
            let lines = pemString.components(separatedBy: .newlines)
            let base64String = lines
                .filter { !$0.contains("-----") && !$0.isEmpty }
                .joined()
            if let decoded = Data(base64Encoded: base64String) {
                derData = decoded
            }
        }
        let thumbprint = RSACrypto.sha1(data: derData)
        return thumbprint.map { String(format: "%02X", $0) }.joined()
    }

    static func thumbprintHex(fromCertificateFile path: String) -> String? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return thumbprintHex(from: data)
        } catch {
            return nil
        }
    }

    static func mgf1Sha256(seed: [UInt8], length: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(length)
        var counter: UInt32 = 0
        while output.count < length {
            var counterBE = counter.bigEndian
            var data = Data(seed)
            data.append(Data(bytes: &counterBE, count: 4))
            let digest = SHA256.hash(data: data)
            output.append(contentsOf: digest)
            counter += 1
        }
        if output.count > length {
            output.removeLast(output.count - length)
        }
        return output
    }

    static func xor(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        let count = min(a.count, b.count)
        var out = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            out[i] = a[i] ^ b[i]
        }
        return out
    }

}
