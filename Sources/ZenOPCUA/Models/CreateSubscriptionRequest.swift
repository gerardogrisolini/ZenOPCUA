//
//  CreateSubscriptionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

class CreateSubscriptionRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .createSubscriptionRequest)
    let requestHeader: RequestHeader
    let requestedPubliscingInterval: Double = 500
    let requestedLifetimeCount: UInt32 = 10000
    let requesteMaxKeepAliveCount: UInt32 = 10
    let maxNotificationsPerPublish: UInt32 = 0
    let publishingEnabled: Bool = true
    let priority: UInt8 = 0
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
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
            requestedPubliscingInterval.bytes +
            requestedLifetimeCount.bytes +
            requesteMaxKeepAliveCount.bytes +
            maxNotificationsPerPublish.bytes +
            publishingEnabled.bytes +
            priority.bytes
    }
}
