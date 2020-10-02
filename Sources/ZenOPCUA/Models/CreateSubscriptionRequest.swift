//
//  CreateSubscriptionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

public struct Subscription: OPCUAEncodable {
    public let requestedPubliscingInterval: Double
    public var requestedLifetimeCount: UInt32
    public var requesteMaxKeepAliveCount: UInt32
    public var maxNotificationsPerPublish: UInt32
    public var publishingEnabled: Bool
    public var priority: UInt8

    public init(
        requestedPubliscingInterval: Double = 250,
        requestedLifetimeCount: UInt32 = 1000,
        requesteMaxKeepAliveCount: UInt32 = 12,
        maxNotificationsPerPublish: UInt32 = 10,
        publishingEnabled: Bool = true,
        priority: UInt8 = 10
    ) {
        self.requestedPubliscingInterval = requestedPubliscingInterval
        self.requestedLifetimeCount = requestedLifetimeCount
        self.requesteMaxKeepAliveCount = requesteMaxKeepAliveCount
        self.maxNotificationsPerPublish = maxNotificationsPerPublish
        self.publishingEnabled = publishingEnabled
        self.priority = priority
    }
    
    internal var bytes: [UInt8] {
        return requestedPubliscingInterval.bytes +
            requestedLifetimeCount.bytes +
            requesteMaxKeepAliveCount.bytes +
            maxNotificationsPerPublish.bytes +
            publishingEnabled.bytes +
            priority.bytes
    }
}

class CreateSubscriptionRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .createSubscriptionRequest)
    let requestHeader: RequestHeader
    let subscription: Subscription
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        subscription: Subscription
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.subscription = subscription
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
            subscription.bytes
    }
}
