//
//  PublishRequest.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

class PublishRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .publishRequest)
    let requestHeader: RequestHeader
    let subscriptionAcknowledgements: [UInt8]

    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        subscriptionAcknowledgements: [UInt32] = []
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.subscriptionAcknowledgements = UInt32(subscriptionAcknowledgements.count).bytes +
            subscriptionAcknowledgements.map { $0.bytes }.reduce([], +)
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }

    var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            subscriptionAcknowledgements
    }
}
