//
//  OpenSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

public class OpenSecureChannelRequest: OPCUAEncodable {
    let secureChannelId: UInt32
    let securityPolicyUri: String
    var senderCertificate: Data = Data()
    var receiverCertificateThumbprint: [UInt8] = []
    let sequenceNumber: UInt32 = 0
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
            sequenceNumber.bytes +
            requestId.bytes

        let body = typeId.bytes +
            requestHeader.bytes +
            clientProtocolVersion.bytes +
            securityTokenRequestType.rawValue.bytes +
            messageSecurityMode.rawValue.bytes

        return header +
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
        requestId: UInt32,
        secureChannelId: UInt32 = 0,
        includeServerThumbprintInOpn: Bool = false
    ) {
        self.secureChannelId = secureChannelId
        // When messageSecurityMode is .none, securityPolicyUri MUST also be None
        // according to OPC UA Part 6, Section 6.7.2
        self.securityPolicyUri = messageSecurityMode == .none ? SecurityPolicies.none.uri : securityPolicy.securityPolicyUri
        self.requestId = requestId
        self.requestHeader = RequestHeader(requestHandle: 0)
        self.securityTokenRequestType = userTokenType
        self.requestedLifetime = requestedLifetime
        self.messageSecurityMode = messageSecurityMode
        
        // When messageSecurityMode is .none, we must NOT send certificate/nonce
        // even if we have a local certificate loaded
        if messageSecurityMode != .none && securityPolicy.localCertificate.count > 0 {
            // We have a local certificate, send it along with nonce
            self.senderCertificate.append(contentsOf: UInt32(securityPolicy.localCertificate.count).bytes)
            self.senderCertificate.append(contentsOf: securityPolicy.localCertificate)

            self.clientNonce.append(contentsOf: UInt32(securityPolicy.clientNonce.count).bytes)
            self.clientNonce.append(contentsOf: securityPolicy.clientNonce)

            // According to OPC UA Part 6, Section 6.7.2:
            // The receiverCertificateThumbprint is NULL when the message is not encrypted.
            // Some servers require it even for Sign-only; keep an explicit compatibility override.
            let shouldIncludeThumbprint = messageSecurityMode == .signAndEncrypt
                || includeServerThumbprintInOpn
                || securityPolicy.securityPolicyUri.securityPolicy == .aes256Sha256RsaPss
            if shouldIncludeThumbprint,
               securityPolicy.remoteCertificateThumbprint.count > 0 {
                self.receiverCertificateThumbprint.append(contentsOf: UInt32(securityPolicy.remoteCertificateThumbprint.count).bytes)
                self.receiverCertificateThumbprint.append(contentsOf: securityPolicy.remoteCertificateThumbprint)
            } else {
                self.receiverCertificateThumbprint.append(contentsOf: UInt32.max.bytes)
            }
        } else {
            // No security - use placeholders
            self.clientNonce.append(contentsOf: UInt32.max.bytes)
            self.senderCertificate.append(contentsOf: UInt32.max.bytes)
            self.receiverCertificateThumbprint.append(contentsOf: UInt32.max.bytes)
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
