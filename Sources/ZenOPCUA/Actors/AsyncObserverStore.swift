import Foundation

actor AsyncObserverStore {
    private var dataChangeContinuations: [UUID: AsyncStream<[DataChange]>.Continuation] = [:]
    private var errorContinuations: [UUID: AsyncStream<Error>.Continuation] = [:]

    func addDataChangeContinuation(_ continuation: AsyncStream<[DataChange]>.Continuation) -> UUID {
        let id = UUID()
        dataChangeContinuations[id] = continuation
        return id
    }

    func removeDataChangeContinuation(_ id: UUID) {
        dataChangeContinuations.removeValue(forKey: id)
    }

    func yieldDataChanges(_ changes: [DataChange]) {
        let continuations = Array(dataChangeContinuations.values)

        for continuation in continuations {
            continuation.yield(changes)
        }
    }

    func addErrorContinuation(_ continuation: AsyncStream<Error>.Continuation) -> UUID {
        let id = UUID()
        errorContinuations[id] = continuation
        return id
    }

    func removeErrorContinuation(_ id: UUID) {
        errorContinuations.removeValue(forKey: id)
    }

    func yieldError(_ error: Error) {
        let continuations = Array(errorContinuations.values)

        for continuation in continuations {
            continuation.yield(error)
        }
    }
}
