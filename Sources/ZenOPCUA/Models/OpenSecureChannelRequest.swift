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
    var securityTokenRequestType: UserTokenType = .anonymous
    var messageSecurityMode: MessageSecurityMode = .none
    var clientNonce: String? = nil
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
            securityTokenRequestType.rawValue.bytes +
            messageSecurityMode.rawValue.bytes +
            clientNonce.bytes +
            requestedLifetime.bytes
    }
    
    init(
        messageSecurityMode: MessageSecurityMode = .none,
        userTokenType: UserTokenType = .anonymous
    ) {
        self.requestHeader = RequestHeader(requestHandle: 0)
        super.init()
        self.secureChannelId = 0
        self.messageSecurityMode = messageSecurityMode
        self.securityTokenRequestType = userTokenType
    }
}

public enum MessageSecurityMode : UInt32 {
    case none = 1
    case sign = 2
    case signAndEncrypt = 3
}

public enum UserTokenType : UInt32 {
    case anonymous = 0      //No token is required.
    case userName = 1       //A username/password token.
    case certificate = 2    //An X509v3 Certificate token.
    case issuedToken = 3    //Any WS-Security defined token.
    case kerberos = 4
}
