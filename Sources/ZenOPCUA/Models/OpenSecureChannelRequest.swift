//
//  OpenSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannelRequest: OpenSecureChannel, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .openSecureChannelRequest)
    let requestHeader: RequestHeader
    var clientProtocolVersion: UInt32 = 0
    let securityTokenRequestType: SecurityTokenRequestType
    let messageSecurityMode: MessageSecurityMode
    var clientNonce: String? = nil
    let requestedLifetime: UInt32
    
    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            securityPolicyUri.rawValue.bytes +
            senderCertificate.bytes +
            receiverCertificateThumbprint.bytes +
            sequenseNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            clientProtocolVersion.bytes +
            securityTokenRequestType.rawValue.bytes +
            messageSecurityMode.rawValue.bytes +
            clientNonce.bytes +
            requestedLifetime.bytes
    }
    
    init(
        messageSecurityMode: MessageSecurityMode,
        securityPolicy: SecurityPolicyUri,
        userTokenType: SecurityTokenRequestType,
        requestedLifetime: UInt32
    ) {
        self.requestHeader = RequestHeader(requestHandle: 0)
        self.messageSecurityMode = messageSecurityMode
        self.securityTokenRequestType = userTokenType
        self.requestedLifetime = requestedLifetime
        super.init(securityPolicyUri: securityPolicy)
        self.secureChannelId = 0
    }
}

public enum MessageSecurityMode : UInt32 {
    case invalid = 0
    case none = 1
    case sign = 2
    case signAndEncrypt = 3
}

public enum SecurityTokenRequestType: UInt32 {
    case issue = 0      //Creates a new security token for a new secure channel.
    case renew = 1      //Creates a new security token for an existing secure channel.
}
