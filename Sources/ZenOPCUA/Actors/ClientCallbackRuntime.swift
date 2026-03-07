actor ClientCallbackRuntime {
    nonisolated private let cache = ClientCallbackCache()

    nonisolated var currentOnDataChanged: OPCUADataChanged? {
        cache.currentOnDataChanged
    }

    nonisolated var currentOnHandlerActivated: OPCUAHandlerChange? {
        cache.currentOnHandlerActivated
    }

    nonisolated var currentOnHandlerRemoved: OPCUAHandlerChange? {
        cache.currentOnHandlerRemoved
    }

    nonisolated var currentOnErrorCaught: OPCUAErrorCaught? {
        cache.currentOnErrorCaught
    }

    nonisolated func updateOnDataChanged(_ callback: OPCUADataChanged?) {
        cache.updateOnDataChanged(callback)
    }

    nonisolated func updateOnHandlerActivated(_ callback: OPCUAHandlerChange?) {
        cache.updateOnHandlerActivated(callback)
    }

    nonisolated func updateOnHandlerRemoved(_ callback: OPCUAHandlerChange?) {
        cache.updateOnHandlerRemoved(callback)
    }

    nonisolated func updateOnErrorCaught(_ callback: OPCUAErrorCaught?) {
        cache.updateOnErrorCaught(callback)
    }
}
