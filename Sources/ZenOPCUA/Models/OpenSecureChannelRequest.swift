//
//  OpenSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation
import CryptoKit

class OpenSecureChannelRequest: OpenSecureChannel, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .openSecureChannelRequest)
    let requestHeader: RequestHeader
    var clientProtocolVersion: UInt32 = 0
    let securityTokenRequestType: SecurityTokenRequestType
    let messageSecurityMode: MessageSecurityMode
    var clientNonce: [UInt8] = []
    let requestedLifetime: UInt32
    
    internal var bytes: [UInt8] {
        let header = secureChannelId.bytes +
            securityPolicyUri.bytes +
            senderCertificate +
            receiverCertificateThumbprint +
            sequenseNumber.bytes +
            requestId.bytes
        let part = header +
            typeId.bytes +
            requestHeader.bytes +
            clientProtocolVersion.bytes +
            securityTokenRequestType.rawValue.bytes +
            messageSecurityMode.rawValue.bytes
        return part +
            clientNonce +
            requestedLifetime.bytes
    }
    
    init(
        messageSecurityMode: MessageSecurityMode,
        securityPolicy policy: SecurityPolicies,
        userTokenType: SecurityTokenRequestType,
        senderCertificate: String?,
        requestedLifetime: UInt32,
        requestId: UInt32
    ) {
        self.requestHeader = RequestHeader(requestHandle: 0)
        self.messageSecurityMode = messageSecurityMode
        self.securityTokenRequestType = userTokenType
        self.clientNonce.append(contentsOf: UInt32.max.bytes)
        self.requestedLifetime = requestedLifetime
        super.init(securityPolicyUri: policy.uri, requestId: requestId)
        self.secureChannelId = 0

        if let certificate = senderCertificate, let data = try? Data(contentsOf: URL(fileURLWithPath: certificate)) {
            let securityPolicy = SecurityPolicy(securityPolicyUri: policy.uri)
            let encoded = securityPolicy.getCertificateEncoded(data: data)
            self.senderCertificate.append(contentsOf: UInt32(encoded.count).bytes)
            self.senderCertificate.append(contentsOf: encoded)
            let digest = Insecure.SHA1.hash(data: encoded)
            self.receiverCertificateThumbprint.append(contentsOf: UInt32(digest.data.count).bytes)
            self.receiverCertificateThumbprint.append(contentsOf: digest.data)
        } else {
            self.senderCertificate.append(contentsOf: UInt32.max.bytes)
            self.receiverCertificateThumbprint.append(contentsOf: UInt32.max.bytes)
        }
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
