//
//  CreateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

class CreateSessionRequest: MessageBase, OPCUAEncodable {
    let securityPolicy: SecurityPolicy
    
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
        clientCertificate: String?,
        securityPolicyUri: String
    ) {
        securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicyUri)

        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.serverUri = serverUri
        self.endpointUrl = endpointUrl
        self.clientDescription = ApplicationDescription(applicationName: applicationName)
        self.sessionName = "\(applicationName)-Session"
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
        
        if securityPolicy.symmetricKeyLength > 0 {
            self.clientNonce.append(contentsOf: UInt32(securityPolicy.symmetricKeyLength).bytes)
            self.clientNonce.append(contentsOf: try! securityPolicy.generateNonce(securityPolicy.symmetricKeyLength))
        } else {
            self.clientNonce.append(contentsOf: UInt32.max.bytes)
        }
        
        if let certificate = clientCertificate, let data = try? Data(contentsOf: URL(fileURLWithPath: certificate)) {
            let encoded = securityPolicy.getCertificateFromPem(data: data)
            self.clientCertificate.append(contentsOf: UInt32(encoded.count).bytes)
            self.clientCertificate.append(contentsOf: encoded)
        } else {
            self.clientCertificate.append(contentsOf: UInt32.max.bytes)
        }
    }
}
