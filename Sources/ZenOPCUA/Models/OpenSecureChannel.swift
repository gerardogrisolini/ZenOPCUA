//
//  OpenSecureChannel.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannel {
    var secureChannelId: UInt32 = 0
    let securityPolicyUri: String
    var senderCertificate: [UInt8] = []
    var receiverCertificateThumbprint: [UInt8] = []
    let sequenseNumber: UInt32
    let requestId: UInt32
    
    init(securityPolicyUri: String, requestId: UInt32) {
        self.securityPolicyUri = securityPolicyUri
        self.sequenseNumber = requestId
        self.requestId = requestId
    }
}
