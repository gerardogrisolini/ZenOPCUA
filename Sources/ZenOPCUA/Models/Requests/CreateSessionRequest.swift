//
//  CreateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

struct CreateSessionRequest: OPCUAEncodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .createSessionRequest)
    let requestHeader: RequestHeader
    let clientDescription: ApplicationDescription
    let serverUri: String
    let endpointUrl: String
    let sessionName: String?
    let clientNonce: [UInt8]
    let clientCertificate: [UInt8]
    let requestedSessionTimeout: Double = 1200000.0
    let maxResponseMessageSize: UInt32 = 2147483647
    
    internal var bytes: [UInt8] {
        let header = self.header.secureChannelId.bytes +
            self.header.tokenId.bytes +
            self.header.sequenceNumber.bytes +
            self.header.requestId.bytes
        let cert = clientNonce + clientCertificate
        let body = typeId.bytes +
            requestHeader.bytes +
            clientDescription.bytes +
            serverUri.bytes +
            endpointUrl.bytes +
            sessionName.bytes +
            cert +
            requestedSessionTimeout.bytes +
            maxResponseMessageSize.bytes
        return header + body
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        serverUri: String,
        endpointUrl: String,
        applicationName: String,
        securityPolicy: SecurityPolicy
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.serverUri = serverUri
        self.endpointUrl = endpointUrl
        self.clientDescription = ApplicationDescription(applicationName: applicationName)
        self.sessionName = "\(applicationName)-Session"
        var nonce: [UInt8] = []
        if securityPolicy.clientNonce.count > 0 {
            nonce.append(contentsOf: UInt32(32).bytes)
            nonce.append(contentsOf: securityPolicy.clientNonce)
        } else {
            nonce.append(contentsOf: UInt32.max.bytes)
        }
        self.clientNonce = nonce

        var certificate: [UInt8] = []
        if securityPolicy.localCertificate.count > 0 {
            certificate.append(contentsOf: UInt32(securityPolicy.localCertificate.count).bytes)
            certificate.append(contentsOf: securityPolicy.localCertificate)
        } else {
            certificate.append(contentsOf: UInt32.max.bytes)
        }
        self.clientCertificate = certificate
    }
}
