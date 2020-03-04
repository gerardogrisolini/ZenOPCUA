//
//  DeleteSubscriptionsRequest.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

class DeleteSubscriptionsRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .deleteSubscriptionsRequest)
    let requestHeader: RequestHeader
    let subscriptionIds: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        subscriptionIds: [UInt32]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.subscriptionIds = UInt32(subscriptionIds.count).bytes + subscriptionIds.map { $0.bytes }.reduce([], +)
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }

    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            subscriptionIds
    }
}
