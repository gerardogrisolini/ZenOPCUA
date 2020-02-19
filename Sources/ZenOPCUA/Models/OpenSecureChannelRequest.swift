//
//  OpenSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannelRequest: OpenSecureChannel, OPCUAEncodable {
    let typeId: TypeId = TypeId(identifierNumeric: .openSecureChannelRequest)
    let requestHeader: RequestHeader
    var clientProtocolVersion: UInt32 = 0
    var securityTokenRequestType: UInt32 = 0 //0x00000000
    var messageSecurityMode: UInt32 = 1 //0x00000001
    var clientNonce: String? = nil //ff ff ff ff
    var requestedLifetime: UInt32 = 600000
    
    var bytes: [UInt8] {
        return secureChannelId.bytes +
            securityPolicyUri.bytes +
            senderCertificate.bytes +
            receiverCertificateThumbprint.bytes +
            sequenseNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            clientProtocolVersion.bytes +
            securityTokenRequestType.bytes +
            messageSecurityMode.bytes +
            clientNonce.bytes +
            requestedLifetime.bytes
    }
    
    init(secureChannelId: UInt32) {
        self.requestHeader = RequestHeader(requestHandle: 0)
        super.init()
        self.secureChannelId = secureChannelId
    }
}
