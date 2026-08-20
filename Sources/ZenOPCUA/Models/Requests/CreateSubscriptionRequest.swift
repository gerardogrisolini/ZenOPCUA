//
//  CreateSubscriptionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

public struct Subscription: OPCUAEncodable, Sendable {
    public let requestedPublishingInterval: Double
    public var requestedLifetimeCount: UInt32
    public var requestedMaxKeepAliveCount: UInt32
    public var maxNotificationsPerPublish: UInt32
    public var publishingEnabled: Bool
    public var priority: UInt8

    public init(
        requestedPublishingInterval: Double = 250,
        requestedLifetimeCount: UInt32 = 1000,
        requestedMaxKeepAliveCount: UInt32 = 12,
        maxNotificationsPerPublish: UInt32 = 10,
        publishingEnabled: Bool = true,
        priority: UInt8 = 10
    ) {
        self.requestedPublishingInterval = requestedPublishingInterval
        self.requestedLifetimeCount = requestedLifetimeCount
        self.requestedMaxKeepAliveCount = requestedMaxKeepAliveCount
        self.maxNotificationsPerPublish = maxNotificationsPerPublish
        self.publishingEnabled = publishingEnabled
        self.priority = priority
    }

    /// Deprecated alias of `requestedPublishingInterval`.
    @available(*, deprecated, renamed: "requestedPublishingInterval")
    public var requestedPubliscingInterval: Double {
        requestedPublishingInterval
    }

    /// Deprecated alias of `requestedMaxKeepAliveCount`.
    @available(*, deprecated, renamed: "requestedMaxKeepAliveCount")
    public var requesteMaxKeepAliveCount: UInt32 {
        requestedMaxKeepAliveCount
    }

    /// Deprecated initializer using the legacy misspelled argument labels.
    @available(*, deprecated, renamed: "init(requestedPublishingInterval:requestedLifetimeCount:requestedMaxKeepAliveCount:maxNotificationsPerPublish:publishingEnabled:priority:)")
    public init(
        requestedPubliscingInterval: Double,
        requestedLifetimeCount: UInt32 = 1000,
        requesteMaxKeepAliveCount: UInt32 = 12,
        maxNotificationsPerPublish: UInt32 = 10,
        publishingEnabled: Bool = true,
        priority: UInt8 = 10
    ) {
        self.init(
            requestedPublishingInterval: requestedPubliscingInterval,
            requestedLifetimeCount: requestedLifetimeCount,
            requestedMaxKeepAliveCount: requesteMaxKeepAliveCount,
            maxNotificationsPerPublish: maxNotificationsPerPublish,
            publishingEnabled: publishingEnabled,
            priority: priority
        )
    }
    
    internal var bytes: [UInt8] {
        return requestedPublishingInterval.bytes +
            requestedLifetimeCount.bytes +
            requestedMaxKeepAliveCount.bytes +
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
