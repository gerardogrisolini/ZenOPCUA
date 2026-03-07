actor AsyncChannelRuntime {
    private var outboundContinuation: AsyncStream<OPCUAFrame>.Continuation?
    private var task: Task<Void, Never>?

    func prepareOutboundStream() -> AsyncStream<OPCUAFrame> {
        var capturedContinuation: AsyncStream<OPCUAFrame>.Continuation?
        let stream = AsyncStream<OPCUAFrame> { continuation in
            capturedContinuation = continuation
        }

        guard let capturedContinuation else {
            preconditionFailure("AsyncStream continuation was not created")
        }

        outboundContinuation = capturedContinuation
        return stream
    }

    func activate(task: Task<Void, Never>) {
        self.task = task
    }

    func write(_ frame: OPCUAFrame) -> Bool {
        guard let outboundContinuation else {
            return false
        }

        switch outboundContinuation.yield(frame) {
        case .enqueued:
            return true
        case .dropped, .terminated:
            return false
        @unknown default:
            return false
        }
    }

    func shutdown() {
        outboundContinuation?.finish()
        outboundContinuation = nil
        task?.cancel()
        task = nil
    }

    func clearFinishedLoop() {
        outboundContinuation = nil
        task = nil
    }
}
