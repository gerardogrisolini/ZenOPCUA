//
//  OpenSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

class OpenSecureChannelRequest: OPCUAEncodable {
    let secureChannelId: UInt32 = 0
    let securityPolicyUri: String
    var senderCertificate: Data = Data()
    var receiverCertificateThumbprint: [UInt8] = []
    let sequenseNumber: UInt32
    let requestId: UInt32
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .openSecureChannelRequest)
    let requestHeader: RequestHeader
    let clientProtocolVersion: UInt32 = 0
    let securityTokenRequestType: SecurityTokenRequestType
    let messageSecurityMode: MessageSecurityMode
    var clientNonce: [UInt8] = []
    let requestedLifetime: UInt32
    
    internal var bytes: [UInt8] {
        let header = secureChannelId.bytes +
            securityPolicyUri.bytes +
            senderCertificate +
            receiverCertificateThumbprint +
            sequenseNumber.bytes
        //print("header: \(header.count)")
        let body = typeId.bytes +
            requestHeader.bytes +
            clientProtocolVersion.bytes +
            securityTokenRequestType.rawValue.bytes +
            messageSecurityMode.rawValue.bytes
        //print("body: \(body.count + clientNonce.count + requestedLifetime.bytes.count)")
        return header +
            requestId.bytes +
            body +
            clientNonce +
            requestedLifetime.bytes
    }
    
    init(
        messageSecurityMode: MessageSecurityMode,
        securityPolicy: SecurityPolicy,
        userTokenType: SecurityTokenRequestType,
        serverCertificate: Data,
        requestedLifetime: UInt32,
        requestId: UInt32
    ) {
        print("Opened SecureChannel with SecurityPolicy \(securityPolicy.securityPolicyUri)")
        
        self.securityPolicyUri = securityPolicy.securityPolicyUri
        self.sequenseNumber = requestId
        self.requestId = requestId
        self.requestHeader = RequestHeader(requestHandle: 0)
        self.securityTokenRequestType = userTokenType
        self.requestedLifetime = requestedLifetime
        self.messageSecurityMode = messageSecurityMode
        
        if serverCertificate.count == 0 {
            self.clientNonce.append(contentsOf: UInt32.max.bytes)
            self.senderCertificate.append(contentsOf: UInt32.max.bytes)
            self.receiverCertificateThumbprint.append(contentsOf: UInt32.max.bytes)
        } else if securityPolicy.localCertificate.count > 0 {
            self.senderCertificate.append(contentsOf: UInt32(securityPolicy.localCertificate.count).bytes)
            self.senderCertificate.append(contentsOf: securityPolicy.localCertificate)

            self.clientNonce.append(contentsOf: UInt32(securityPolicy.clientNonce.count).bytes)
            self.clientNonce.append(contentsOf: securityPolicy.clientNonce)

            let thumbprint = securityPolicy.remoteCertificateThumbprint
            self.receiverCertificateThumbprint.append(contentsOf: UInt32(thumbprint.count).bytes)
            self.receiverCertificateThumbprint.append(contentsOf: thumbprint)
        }
    }
}

public enum MessageSecurityMode : UInt32 {
    //case invalid = 0
    case none = 1
    case sign = 2
    case signAndEncrypt = 3
}

public enum SecurityTokenRequestType: UInt32 {
    case issue = 0      //Creates a new security token for a new secure channel.
    case renew = 1      //Creates a new security token for an existing secure channel.
}
