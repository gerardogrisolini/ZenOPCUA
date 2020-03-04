//
//  OpenSecureChannel.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannel {
    var secureChannelId: UInt32 = 0
    let securityPolicyUri: SecurityPolicyUri
    var senderCertificate: String? = nil
    var receiverCertificateThumbprint: String? = nil
    var sequenseNumber: UInt32 = 1
    var requestId: UInt32 = 1
    
    init(securityPolicyUri: SecurityPolicyUri) {
        self.securityPolicyUri = securityPolicyUri
    }
}

public enum SecurityPolicyUri: String {
    case none = "http://opcfoundation.org/UA/SecurityPolicy#None"
    case basic256 = "http://opcfoundation.org/UA/SecurityPolicy#Basic256"
    case basic256Sha256 = "http://opcfoundation.org/UA/SecurityPolicy#Basic256Sha256"
    case basic128Rsa15 = "http://opcfoundation.org/UA/SecurityPolicy#Basic128Rsa15"
    case aes256Sha256RsaPss = "http://opcfoundation.org/UA/SecurityPolicy#Aes256_Sha256_RsaPss"
    case aes128Sha256RsaOaep = "http://opcfoundation.org/UA/SecurityPolicy#Aes128_Sha256_RsaOaep"
}
