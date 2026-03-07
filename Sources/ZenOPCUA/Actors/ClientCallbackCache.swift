import NIOConcurrencyHelpers

struct ClientCallbackCache: Sendable {
    private let box = NIOLockedValueBox(ClientCallbackState())

    var currentOnDataChanged: OPCUADataChanged? {
        box.withLockedValue { state in
            state.onDataChanged
        }
    }

    var currentOnHandlerActivated: OPCUAHandlerChange? {
        box.withLockedValue { state in
            state.onHandlerActivated
        }
    }

    var currentOnHandlerRemoved: OPCUAHandlerChange? {
        box.withLockedValue { state in
            state.onHandlerRemoved
        }
    }

    var currentOnErrorCaught: OPCUAErrorCaught? {
        box.withLockedValue { state in
            state.onErrorCaught
        }
    }

    func updateOnDataChanged(_ callback: OPCUADataChanged?) {
        box.withLockedValue { state in
            state.onDataChanged = callback
        }
    }

    func updateOnHandlerActivated(_ callback: OPCUAHandlerChange?) {
        box.withLockedValue { state in
            state.onHandlerActivated = callback
        }
    }

    func updateOnHandlerRemoved(_ callback: OPCUAHandlerChange?) {
        box.withLockedValue { state in
            state.onHandlerRemoved = callback
        }
    }

    func updateOnErrorCaught(_ callback: OPCUAErrorCaught?) {
        box.withLockedValue { state in
            state.onErrorCaught = callback
        }
    }
}
