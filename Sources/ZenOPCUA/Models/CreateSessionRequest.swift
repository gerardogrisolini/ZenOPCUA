//
//  CreateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class CreateSessionRequest: MessageBase, OPCUAEncodable {

    let typeId: NodeIdNumeric = NodeIdNumeric(method: .createSessionRequest)
    let requestHeader: RequestHeader
    let clientDescription: ApplicationDescription = ApplicationDescription()
    var serverUri: String? = nil
    let endpointUrl: String
    var sessionName: String? = nil
    var clientNonce: String? = nil
    var clientCertificate: String? = nil
    let requestedSessionTimeout: Double = 1200000.0
    let maxResponseMessageSize: UInt32 = 2147483647
    
    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            clientDescription.bytes +
            serverUri.bytes +
            endpointUrl.bytes +
            sessionName.bytes +
            clientNonce.bytes +
            clientCertificate.bytes +
            requestedSessionTimeout.bytes +
            maxResponseMessageSize.bytes
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        endpointUrl: String
    ) {
        self.sessionName = "ZenOPCUA-session1"
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.endpointUrl = endpointUrl
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}
