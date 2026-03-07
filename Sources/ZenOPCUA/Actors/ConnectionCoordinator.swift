import NIO

actor ConnectionCoordinator {
    enum Phase: Sendable {
        case idle
        case connecting
        case connected
        case disconnecting
        case waitingToReconnect
        case reconnecting
    }

    private let snapshotProvider: ConnectionCoordinatorSnapshotProvider
    private var channel: Channel?
    private var eventLoop: EventLoop?
    private var disconnectRequested = false
    private var phase: Phase = .idle
    private var reconnectEnabled = false
    private var isAcknowledging = false
    private var isUpgradingToSecure = false
    private var shouldUseUnsignedBootstrapSecurity = true
    private var opnThumbprintRetryDone = false

    init(snapshotProvider: ConnectionCoordinatorSnapshotProvider) {
        self.snapshotProvider = snapshotProvider
    }

    static func buildInitialSnapshot() -> ConnectionCoordinatorSnapshot {
        buildSnapshot(
            channel: nil,
            eventLoop: nil,
            disconnectRequested: false,
            phase: .idle,
            reconnectEnabled: false,
            isAcknowledging: false,
            isUpgradingToSecure: false,
            shouldUseUnsignedBootstrapSecurity: true,
            opnThumbprintRetryDone: false
        )
    }

    private static func buildSnapshot(
        channel: Channel?,
        eventLoop: EventLoop?,
        disconnectRequested: Bool,
        phase: Phase,
        reconnectEnabled: Bool,
        isAcknowledging: Bool,
        isUpgradingToSecure: Bool,
        shouldUseUnsignedBootstrapSecurity: Bool,
        opnThumbprintRetryDone: Bool
    ) -> ConnectionCoordinatorSnapshot {
        let canBeginConnect: Bool
        switch phase {
        case .idle:
            canBeginConnect = true
        case .disconnecting:
            canBeginConnect = disconnectRequested
        case .connecting, .connected, .waitingToReconnect, .reconnecting:
            canBeginConnect = false
        }

        let canBeginDisconnect: Bool
        switch phase {
        case .connected, .connecting, .reconnecting:
            canBeginDisconnect = true
        case .idle, .disconnecting, .waitingToReconnect:
            canBeginDisconnect = false
        }

        let canStartTransport: Bool
        switch phase {
        case .connecting, .reconnecting:
            canStartTransport = true
        case .idle, .connected, .disconnecting, .waitingToReconnect:
            canStartTransport = false
        }

        return ConnectionCoordinatorSnapshot(
            currentChannel: channel,
            currentEventLoop: eventLoop,
            shouldAttemptReconnect: !disconnectRequested,
            currentPhase: phase,
            canBeginConnect: canBeginConnect,
            canBeginDisconnect: canBeginDisconnect,
            canStartTransport: canStartTransport,
            lifecycleReconnectEnabled: reconnectEnabled,
            lifecycleIsAcknowledging: isAcknowledging,
            lifecycleIsUpgradingToSecure: isUpgradingToSecure,
            shouldUseUnsignedBootstrapSecurityOnCurrentTransport: shouldUseUnsignedBootstrapSecurity,
            hasRetriedOpnThumbprintCompatibility: opnThumbprintRetryDone
        )
    }

    private func refreshSnapshot() {
        snapshotProvider.store(
            Self.buildSnapshot(
                channel: channel,
                eventLoop: eventLoop,
                disconnectRequested: disconnectRequested,
                phase: phase,
                reconnectEnabled: reconnectEnabled,
                isAcknowledging: isAcknowledging,
                isUpgradingToSecure: isUpgradingToSecure,
                shouldUseUnsignedBootstrapSecurity: shouldUseUnsignedBootstrapSecurity,
                opnThumbprintRetryDone: opnThumbprintRetryDone
            )
        )
    }

    func prepareForConnect() {
        disconnectRequested = false
        phase = .connecting
        isAcknowledging = true
        refreshSnapshot()
    }

    func prepareForDisconnect() {
        disconnectRequested = true
        phase = .disconnecting
        refreshSnapshot()
    }

    func prepareForReconnect() {
        disconnectRequested = false
        phase = .reconnecting
        refreshSnapshot()
    }

    func setReconnectEnabled(_ enabled: Bool) {
        reconnectEnabled = enabled
        refreshSnapshot()
    }

    func completeAcknowledge() {
        isAcknowledging = false
        refreshSnapshot()
    }

    func setUpgradingToSecure(_ isUpgradingToSecure: Bool) {
        self.isUpgradingToSecure = isUpgradingToSecure
        refreshSnapshot()
    }

    func markSecuredTransportActive() {
        shouldUseUnsignedBootstrapSecurity = false
        refreshSnapshot()
    }

    func resetUnsignedBootstrapSecurity(hasRemoteCertificate: Bool) {
        guard hasRemoteCertificate == false else { return }
        shouldUseUnsignedBootstrapSecurity = true
        refreshSnapshot()
    }

    func markOpnThumbprintRetryDone() {
        opnThumbprintRetryDone = true
        refreshSnapshot()
    }

    func resetOpnThumbprintRetry() {
        opnThumbprintRetryDone = false
        refreshSnapshot()
    }

    func disableReconnect() {
        reconnectEnabled = false
        refreshSnapshot()
    }

    func enterReconnectBackoff() -> Bool {
        guard !disconnectRequested, phase != .disconnecting else {
            return false
        }
        phase = .waitingToReconnect
        refreshSnapshot()
        return true
    }

    func resumeReconnectFromBackoff() -> Bool {
        guard !disconnectRequested, phase == .waitingToReconnect else {
            return false
        }
        phase = .reconnecting
        refreshSnapshot()
        return true
    }

    func setChannel(_ channel: Channel) {
        self.channel = channel
        self.eventLoop = channel.eventLoop
        self.disconnectRequested = false
        self.phase = .connected
        refreshSnapshot()
    }

    func clearConnection() {
        channel = nil
        eventLoop = nil
        if phase != .reconnecting && phase != .waitingToReconnect {
            phase = .idle
        }
        refreshSnapshot()
    }

    func markStartFailed() {
        channel = nil
        eventLoop = nil
        phase = disconnectRequested ? .disconnecting : .idle
        isAcknowledging = false
        refreshSnapshot()
    }
}
