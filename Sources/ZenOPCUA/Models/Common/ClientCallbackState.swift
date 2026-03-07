struct ClientCallbackState: Sendable {
    var onDataChanged: OPCUADataChanged?
    var onHandlerActivated: OPCUAHandlerChange?
    var onHandlerRemoved: OPCUAHandlerChange?
    var onErrorCaught: OPCUAErrorCaught?
}
