actor ConnectionCoordinatorSnapshotProvider {
    nonisolated private let cache: ConnectionCoordinatorSnapshotCache

    init(snapshot: ConnectionCoordinatorSnapshot) {
        self.cache = ConnectionCoordinatorSnapshotCache(snapshot: snapshot)
    }

    nonisolated var currentSnapshot: ConnectionCoordinatorSnapshot {
        cache.currentSnapshot
    }

    nonisolated func store(_ snapshot: ConnectionCoordinatorSnapshot) {
        cache.store(snapshot)
    }
}
