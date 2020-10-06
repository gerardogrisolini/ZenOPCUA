//
//  CreateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

class CreateSessionRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .createSessionRequest)
    let requestHeader: RequestHeader
    let clientDescription: ApplicationDescription
    let serverUri: String
    let endpointUrl: String
    var sessionName: String? = nil
    var clientNonce: [UInt8] = []
    var clientCertificate: [UInt8] = []
    let requestedSessionTimeout: Double = 1200000.0
    let maxResponseMessageSize: UInt32 = 2147483647
    
    internal var bytes: [UInt8] {
        let header = secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes
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
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        serverUri: String,
        endpointUrl: String,
        applicationName: String,
        securityPolicy: SecurityPolicy
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.serverUri = serverUri
        self.endpointUrl = endpointUrl
        self.clientDescription = ApplicationDescription(applicationName: applicationName)
        self.sessionName = "\(applicationName)-Session"
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
        
        if securityPolicy.clientNonce.count > 0 {
            self.clientNonce.append(contentsOf: UInt32(32).bytes)
            self.clientNonce.append(contentsOf: securityPolicy.clientNonce)
        } else {
            self.clientNonce.append(contentsOf: UInt32.max.bytes)
        }
        
        if securityPolicy.localCertificate.count > 0 {
            self.clientCertificate.append(contentsOf: UInt32(securityPolicy.localCertificate.count).bytes)
            self.clientCertificate.append(contentsOf: securityPolicy.localCertificate)
        } else {
            self.clientCertificate.append(contentsOf: UInt32.max.bytes)
        }
    }
}
