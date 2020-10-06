//
//  SecurityAlgorithm.swift
//  
//
//  Created by Gerardo Grisolini on 03/10/2020.
//

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
