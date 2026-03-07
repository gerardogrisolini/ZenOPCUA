//
//  CreateSubscriptionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

public struct Subscription: OPCUAEncodable, Sendable {
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

struct CreateSubscriptionRequest: OPCUAEncodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .createSubscriptionRequest)
    let requestHeader: RequestHeader
    let subscription: Subscription
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        subscription: Subscription
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
        self.subscription = subscription
    }

    internal var bytes: [UInt8] {
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            subscription.bytes
    }
}
