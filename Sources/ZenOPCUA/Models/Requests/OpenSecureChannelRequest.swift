//
//  OpenSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

public struct OpenSecureChannelRequest: OPCUAEncodable, Sendable {
    let secureChannelId: UInt32
    let securityPolicyUri: String
    let senderCertificate: Data
    let receiverCertificateThumbprint: [UInt8]
    let sequenceNumber: UInt32 = 0
    let requestId: UInt32
    let typeId: NodeValue = NodeValue(method: .openSecureChannelRequest)
    let requestHeader: RequestHeader
    let clientProtocolVersion: UInt32 = 0
    let securityTokenRequestType: SecurityTokenRequestType
    let messageSecurityMode: MessageSecurityMode
    let clientNonce: [UInt8]
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

        var senderCertificate: Data = Data()
        var clientNonce: [UInt8] = []
        var receiverCertificateThumbprint: [UInt8] = []

        // When messageSecurityMode is .none, we must NOT send certificate/nonce
        // even if we have a local certificate loaded
        if messageSecurityMode != .none && securityPolicy.localCertificate.count > 0 {
            // We have a local certificate, send it along with nonce
            senderCertificate.append(contentsOf: UInt32(securityPolicy.localCertificate.count).bytes)
            senderCertificate.append(contentsOf: securityPolicy.localCertificate)

            clientNonce.append(contentsOf: UInt32(securityPolicy.clientNonce.count).bytes)
            clientNonce.append(contentsOf: securityPolicy.clientNonce)

            // According to OPC UA Part 6, Section 6.7.2:
            // The receiverCertificateThumbprint is NULL when the message is not encrypted.
            // Some servers require it even for Sign-only; keep an explicit compatibility override.
            let shouldIncludeThumbprint = messageSecurityMode == .signAndEncrypt
                || includeServerThumbprintInOpn
                || securityPolicy.securityPolicyUri.securityPolicy == .aes256Sha256RsaPss
            if shouldIncludeThumbprint,
               securityPolicy.remoteCertificateThumbprint.count > 0 {
                receiverCertificateThumbprint.append(contentsOf: UInt32(securityPolicy.remoteCertificateThumbprint.count).bytes)
                receiverCertificateThumbprint.append(contentsOf: securityPolicy.remoteCertificateThumbprint)
            } else {
                receiverCertificateThumbprint.append(contentsOf: UInt32.max.bytes)
            }
        } else {
            // No security - use placeholders
            clientNonce.append(contentsOf: UInt32.max.bytes)
            senderCertificate.append(contentsOf: UInt32.max.bytes)
            receiverCertificateThumbprint.append(contentsOf: UInt32.max.bytes)
        }

        self.senderCertificate = senderCertificate
        self.clientNonce = clientNonce
        self.receiverCertificateThumbprint = receiverCertificateThumbprint
    }
}

public enum MessageSecurityMode : UInt32, Sendable {
    //case invalid = 0
    case none = 1
    case sign = 2
    case signAndEncrypt = 3
}

public enum SecurityTokenRequestType: UInt32, Sendable {
    case issue = 0      //Creates a new security token for a new secure channel.
    case renew = 1      //Creates a new security token for an existing secure channel.
}
