import NIOConcurrencyHelpers

/// Tracks the last notificationMessage.sequenceNumber received for each
/// subscription, so PublishRequest can acknowledge the correct pairs.
/// Follows the ChannelSessionRuntime pattern: actor façade over a locked
/// cache that also allows synchronous (nonisolated) reads from the
/// EventLoop-confined dispatch path.
actor SubscriptionAckRuntime {
    private struct AckCache: Sendable {
        private let box = NIOLockedValueBox<[UInt32: UInt32]>([:])

        func record(_ sequenceNumber: UInt32, for subscriptionId: UInt32) {
            box.withLockedValue { $0[subscriptionId] = sequenceNumber }
        }

        func currentSequenceNumber(for subscriptionId: UInt32) -> UInt32? {
            box.withLockedValue { $0[subscriptionId] }
        }

        /// Returns the acknowledgement pairs to send with a PublishRequest:
        /// - empty subscriptionIds → every tracked subscription;
        /// - non-empty → only the requested subscriptions with a known sequence number.
        func acknowledgements(forSubscriptionIds subscriptionIds: [UInt32]) -> [SubscriptionAcknowledgement] {
            box.withLockedValue { map in
                if subscriptionIds.isEmpty {
                    return map
                        .map { SubscriptionAcknowledgement(subscriptionId: $0.key, sequenceNumber: $0.value) }
                        .sorted { $0.subscriptionId < $1.subscriptionId }
                }
                return subscriptionIds.compactMap { subscriptionId in
                    guard let sequenceNumber = map[subscriptionId] else { return nil }
                    return SubscriptionAcknowledgement(subscriptionId: subscriptionId, sequenceNumber: sequenceNumber)
                }
            }
        }
    }

    nonisolated private let cache = AckCache()

    nonisolated func record(_ sequenceNumber: UInt32, for subscriptionId: UInt32) {
        cache.record(sequenceNumber, for: subscriptionId)
    }

    nonisolated func currentSequenceNumber(for subscriptionId: UInt32) -> UInt32? {
        cache.currentSequenceNumber(for: subscriptionId)
    }

    nonisolated func acknowledgements(forSubscriptionIds subscriptionIds: [UInt32]) -> [SubscriptionAcknowledgement] {
        cache.acknowledgements(forSubscriptionIds: subscriptionIds)
    }
}
