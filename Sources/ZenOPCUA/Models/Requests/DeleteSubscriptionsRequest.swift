//
//  DeleteSubscriptionsRequest.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

struct DeleteSubscriptionsRequest: OPCUAEncodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .deleteSubscriptionsRequest)
    let requestHeader: RequestHeader
    let subscriptionIds: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        subscriptionIds: [UInt32]
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
        self.subscriptionIds = UInt32(subscriptionIds.count).bytes + subscriptionIds.map { $0.bytes }.reduce([], +)
    }

    internal var bytes: [UInt8] {
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            subscriptionIds
    }
}
