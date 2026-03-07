import NIO

struct ConnectionCoordinatorSnapshot: Sendable {
    let currentChannel: Channel?
    let currentEventLoop: EventLoop?
    let shouldAttemptReconnect: Bool
    let currentPhase: ConnectionCoordinator.Phase
    let canBeginConnect: Bool
    let canBeginDisconnect: Bool
    let canStartTransport: Bool
    let lifecycleReconnectEnabled: Bool
    let lifecycleIsAcknowledging: Bool
    let lifecycleIsUpgradingToSecure: Bool
    let shouldUseUnsignedBootstrapSecurityOnCurrentTransport: Bool
    let hasRetriedOpnThumbprintCompatibility: Bool
}
