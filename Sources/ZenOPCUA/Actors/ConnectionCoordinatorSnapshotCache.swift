import NIOConcurrencyHelpers

struct ConnectionCoordinatorSnapshotCache: Sendable {
    private let box: NIOLockedValueBox<ConnectionCoordinatorSnapshot>

    init(snapshot: ConnectionCoordinatorSnapshot) {
        self.box = NIOLockedValueBox(snapshot)
    }

    var currentSnapshot: ConnectionCoordinatorSnapshot {
        box.withLockedValue { $0 }
    }

    func store(_ snapshot: ConnectionCoordinatorSnapshot) {
        box.withLockedValue { $0 = snapshot }
    }
}
