//
//  OpenSecureChannel.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannel {
    var secureChannelId: UInt32 = 0
    var securityPolicyUri: String = "http://opcfoundation.org/UA/SecurityPolicy#None"
    var senderCertificate: String? = nil
    var receiverCertificateThumbprint: String? = nil
    var sequenseNumber: UInt32 = 1
    var requestId: UInt32 = 1
    
    init() {
    }
}
