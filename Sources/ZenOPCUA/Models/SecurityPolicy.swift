//
//  SecurityPolicy.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import NIO
import NIOSSL
import Crypto

enum SecurityPolicies: String {
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
    
    func getAsymmetricKeyLength(certificate: NIOSSLCertificate) -> Int {
        do {
            let publicKey = try certificate.extractPublicKey()
            return try publicKey.toSPKIBytes().count
        } catch {
            print(error)
            return 0
        }
    }
    
    func getAsymmetricSignatureSize(certificate: NIOSSLCertificate, algorithm: SecurityAlgorithm) -> Int {
        switch (algorithm) {
        case .rsaSha1, .rsaSha256, .rsaSha256Pss:
            return (getAsymmetricKeyLength(certificate: certificate) + 7) / 8
        default:
            return 0
        }
    }

    func getAsymmetricCipherTextBlockSize(certificate: NIOSSLCertificate, algorithm: SecurityAlgorithm) -> Int {
        switch (algorithm) {
        case .rsa15, .rsaOaepSha1, .rsaOaepSha256:
            return (getAsymmetricKeyLength(certificate: certificate) + 7) / 8
        default:
            return 1
        }
    }
    
    func getAsymmetricPlainTextBlockSize(certificate: NIOSSLCertificate, algorithm: SecurityAlgorithm) -> Int {
        switch (algorithm) {
        case .rsa15:
            return (getAsymmetricKeyLength(certificate: certificate) + 7) / 8 - 11
        case .rsaOaepSha1:
            return (getAsymmetricKeyLength(certificate: certificate) + 7) / 8 - 42
        case .rsaOaepSha256:
            return (getAsymmetricKeyLength(certificate: certificate) + 7) / 8 - 66
        default:
            return 1
        }
    }

    /*
    private func getAndInitializeCipher(_ serverCertificate: NIOSSLCertificate, _ securityPolicy: SecurityPolicy) throws -> Cipher {        
//        String transformation = securityPolicy.getAsymmetricEncryptionAlgorithm().getTransformation();
//        Cipher cipher = Cipher.getInstance(transformation);
//        cipher.init(Cipher.ENCRYPT_MODE, serverCertificate.getPublicKey());

        let key = try serverCertificate.extractPublicKey()
        let b = try key.toSPKIBytes()
        let cipher = try Rabbit(key: b)

        return cipher
    }
    */
    
    func sign(value: String) -> String {
        
        return value
    }

    func crypt(password: String, serverNonce: [UInt8], serverCertificate: [UInt8]) throws -> [UInt8] {
        let bufferAllocator = ByteBufferAllocator()

        var buffer = bufferAllocator.buffer(capacity: password.bytes.count + serverNonce.count)
        buffer.writeBytes(password.bytes + serverNonce)
        
        let certificate = try NIOSSLCertificate(bytes: .init(serverCertificate), format: .der)
       
        let plainTextBlockSize: Int = getAsymmetricPlainTextBlockSize(
            certificate: certificate,
            algorithm: asymmetricEncryptionAlgorithm
        )
        let cipherTextBlockSize: Int = getAsymmetricCipherTextBlockSize(
            certificate: certificate,
            algorithm: asymmetricEncryptionAlgorithm
        )
        let blockCount: Int = (buffer.capacity + plainTextBlockSize - 1) / plainTextBlockSize

        //let cipher = try getAndInitializeCipher(certificate, SecurityPolicy(securityPolicyUri: securityPolicyUri))

        let key = SymmetricKey(size: .bits256)
        var cipherTextNioBuffer = bufferAllocator.buffer(capacity: cipherTextBlockSize * blockCount)
             
        for blockNumber in 0..<blockCount {
            let position = blockNumber * plainTextBlockSize
            let limit = min(buffer.readableBytes, (blockNumber + 1) * plainTextBlockSize)
            if position > limit { continue }
            
            let bytes = buffer.getBytes(at: position, length: limit - position)!
            //let encrypted = try AES.GCM.seal(bytes, using: key)
            let encrypted = try ChaChaPoly.seal(bytes, using: key)
            
            cipherTextNioBuffer.writeBytes(encrypted.combined)
         }

        var count = cipherTextNioBuffer.readableBytes - 1
        buffer.clear()
        buffer.reserveCapacity(count + 1)
        
        while count >= 0 {
            buffer.writeBytes(cipherTextNioBuffer.getBytes(at: count, length: 1)!)
            count -= 1
        }

        return buffer.getBytes(at: 0, length: buffer.readableBytes)!
    }
}
