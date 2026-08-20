//
//  PublishRequest.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

/// A single acknowledgement sent with a PublishRequest: tells the server the
/// last notificationMessage sequence number received for a subscription.
/// Wire format (Part 4, PublishRequest.subscriptionAcknowledgements):
/// arrayLength(4) + per-item { subscriptionId(4) + sequenceNumber(4) }.
struct SubscriptionAcknowledgement: OPCUAEncodable, Equatable, Sendable {
    let subscriptionId: UInt32
    let sequenceNumber: UInt32

    internal var bytes: [UInt8] {
        return subscriptionId.bytes + sequenceNumber.bytes
    }
}

struct PublishRequest: OPCUAEncodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .publishRequest)
    let requestHeader: RequestHeader
    let subscriptionAcknowledgements: [SubscriptionAcknowledgement]

    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        subscriptionAcknowledgements: [SubscriptionAcknowledgement] = []
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
        self.subscriptionAcknowledgements = subscriptionAcknowledgements
    }

    internal var bytes: [UInt8] {
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            UInt32(subscriptionAcknowledgements.count).bytes +
            subscriptionAcknowledgements.map { $0.bytes }.reduce([], +)
    }
}
