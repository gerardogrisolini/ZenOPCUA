import Foundation
import NIOConcurrencyHelpers

private struct SecurityPolicyBox: Sendable {
    private let box: NIOLockedValueBox<SecurityPolicy>

    init(securityPolicy: SecurityPolicy) {
        self.box = NIOLockedValueBox(securityPolicy)
    }

    var currentSecurityPolicy: SecurityPolicy {
        box.withLockedValue { $0 }
    }

    func replace(with securityPolicy: SecurityPolicy) {
        box.withLockedValue { $0 = securityPolicy }
    }
}

private final class SecuritySessionState: Sendable {
    let cryptoContext: RSACrypto.RuntimeContext
    private let securityPolicyBox: SecurityPolicyBox

    init(
        cryptoContext: RSACrypto.RuntimeContext,
        securityPolicy: SecurityPolicy,
        messageSecurityMode: MessageSecurityMode,
        includeServerThumbprintInOpn: Bool
    ) {
        self.cryptoContext = cryptoContext
        self.securityPolicyBox = SecurityPolicyBox(securityPolicy: securityPolicy)
        syncSecurityPolicy(
            messageSecurityMode: messageSecurityMode,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn
        )
    }

    var securityPolicy: SecurityPolicy {
        securityPolicyBox.currentSecurityPolicy
    }

    func updateConnectionSettings(messageSecurityMode: MessageSecurityMode, includeServerThumbprintInOpn: Bool) {
        securityPolicy.updateConnectionSettings(
            messageSecurityMode: messageSecurityMode,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn
        )
    }

    func replaceSecurityPolicy(
        uri: String,
        messageSecurityMode: MessageSecurityMode,
        includeServerThumbprintInOpn: Bool
    ) {
        securityPolicyBox.replace(with: SecurityPolicy(securityPolicyUri: uri))
        syncSecurityPolicy(
            messageSecurityMode: messageSecurityMode,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn
        )
    }

    private func syncSecurityPolicy(messageSecurityMode: MessageSecurityMode, includeServerThumbprintInOpn: Bool) {
        securityPolicy.updateCryptoContext(cryptoContext)
        securityPolicy.updateConnectionSettings(
            messageSecurityMode: messageSecurityMode,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn
        )
    }
}

private actor ProtocolSessionState {
    private struct ProtocolSessionData: Sendable {
        var messageSecurityMode: MessageSecurityMode
        var bufferSize: Int
        var includeServerThumbprintInOpn: Bool
        var expectedServerThumbprint: Data?
        var sequenceNumber = UInt32(1)
    }

    private struct ProtocolSessionCache: Sendable {
        private let box: NIOLockedValueBox<ProtocolSessionData>

        init(
            messageSecurityMode: MessageSecurityMode,
            bufferSize: Int,
            includeServerThumbprintInOpn: Bool,
            expectedServerThumbprint: Data?
        ) {
            self.box = NIOLockedValueBox(
                ProtocolSessionData(
                    messageSecurityMode: messageSecurityMode,
                    bufferSize: bufferSize,
                    includeServerThumbprintInOpn: includeServerThumbprintInOpn,
                    expectedServerThumbprint: expectedServerThumbprint
                )
            )
        }

        var currentMessageSecurityMode: MessageSecurityMode {
            box.withLockedValue { state in
                state.messageSecurityMode
            }
        }

        func updateMessageSecurityMode(_ messageSecurityMode: MessageSecurityMode) {
            box.withLockedValue { state in
                state.messageSecurityMode = messageSecurityMode
            }
        }

        var currentBufferSize: Int {
            box.withLockedValue { state in
                state.bufferSize
            }
        }

        func updateBufferSize(_ bufferSize: Int) {
            box.withLockedValue { state in
                state.bufferSize = bufferSize
            }
        }

        var currentIncludeServerThumbprintInOpn: Bool {
            box.withLockedValue { state in
                state.includeServerThumbprintInOpn
            }
        }

        func updateIncludeServerThumbprintInOpn(_ includeServerThumbprintInOpn: Bool) {
            box.withLockedValue { state in
                state.includeServerThumbprintInOpn = includeServerThumbprintInOpn
            }
        }

        var currentExpectedServerThumbprint: Data? {
            box.withLockedValue { state in
                state.expectedServerThumbprint
            }
        }

        func updateExpectedServerThumbprint(_ expectedServerThumbprint: Data?) {
            box.withLockedValue { state in
                state.expectedServerThumbprint = expectedServerThumbprint
            }
        }

        func resetSequenceNumber() {
            box.withLockedValue { state in
                state.sequenceNumber = 0
            }
        }

        func nextSequenceNumber() -> UInt32 {
            box.withLockedValue { state in
                state.sequenceNumber += 1
                return state.sequenceNumber
            }
        }
    }

    nonisolated private let cache: ProtocolSessionCache

    init(
        messageSecurityMode: MessageSecurityMode,
        bufferSize: Int,
        includeServerThumbprintInOpn: Bool,
        expectedServerThumbprint: Data?
    ) {
        self.cache = ProtocolSessionCache(
            messageSecurityMode: messageSecurityMode,
            bufferSize: bufferSize,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn,
            expectedServerThumbprint: expectedServerThumbprint
        )
    }

    nonisolated var messageSecurityMode: MessageSecurityMode {
        get { cache.currentMessageSecurityMode }
        set { cache.updateMessageSecurityMode(newValue) }
    }

    nonisolated var bufferSize: Int {
        get { cache.currentBufferSize }
        set { cache.updateBufferSize(newValue) }
    }

    nonisolated var includeServerThumbprintInOpn: Bool {
        get { cache.currentIncludeServerThumbprintInOpn }
        set { cache.updateIncludeServerThumbprintInOpn(newValue) }
    }

    nonisolated var expectedServerThumbprint: Data? {
        get { cache.currentExpectedServerThumbprint }
        set { cache.updateExpectedServerThumbprint(newValue) }
    }

    nonisolated func resetSequenceNumber() {
        cache.resetSequenceNumber()
    }

    nonisolated func nextSequenceNumber() -> UInt32 {
        cache.nextSequenceNumber()
    }
}

// Concurrency: confined to the channel's EventLoop.
final class OPCUAConnectionState: Sendable {
    private let securitySessionState: SecuritySessionState
    private let protocolSessionState: ProtocolSessionState
    private let verifyReceivedSignaturesBox: NIOLockedValueBox<Bool>
    var verifyReceivedSignatures: Bool {
        get { verifyReceivedSignaturesBox.withLockedValue { $0 } }
        set { verifyReceivedSignaturesBox.withLockedValue { $0 = newValue } }
    }
    var messageSecurityMode: MessageSecurityMode {
        get { protocolSessionState.messageSecurityMode }
        set {
            protocolSessionState.messageSecurityMode = newValue
            securitySessionState.updateConnectionSettings(
                messageSecurityMode: newValue,
                includeServerThumbprintInOpn: includeServerThumbprintInOpn
            )
        }
    }
    var bufferSize: Int {
        get { protocolSessionState.bufferSize }
        set { protocolSessionState.bufferSize = newValue }
    }
    var includeServerThumbprintInOpn: Bool {
        get { protocolSessionState.includeServerThumbprintInOpn }
        set {
            protocolSessionState.includeServerThumbprintInOpn = newValue
            securitySessionState.updateConnectionSettings(
                messageSecurityMode: messageSecurityMode,
                includeServerThumbprintInOpn: newValue
            )
        }
    }
    var expectedServerThumbprint: Data? {
        get { protocolSessionState.expectedServerThumbprint }
        set { protocolSessionState.expectedServerThumbprint = newValue }
    }
    
    var isAcknowledgeSecure: Bool {
        messageSecurityMode != .none && securitySessionState.securityPolicy.remoteCertificate.count == 0
    }

    var hasRemoteCertificate: Bool {
        securitySessionState.securityPolicy.remoteCertificate.isEmpty == false
    }

    var hasSymmetricKeys: Bool {
        securitySessionState.cryptoContext.getSecurityKeys() != nil
    }

    var clientNonce: [UInt8] {
        securitySessionState.securityPolicy.clientNonce
    }

    var symmetricSignatureKeySize: Int {
        securitySessionState.securityPolicy.symmetricSignatureKeySize
    }

    var symmetricEncryptionKeySize: Int {
        securitySessionState.securityPolicy.symmetricEncryptionKeySize
    }

    var symmetricBlockSize: Int {
        securitySessionState.securityPolicy.symmetricBlockSize
    }

    var keyDerivationAlgorithm: SecurityAlgorithm {
        securitySessionState.securityPolicy.keyDerivationAlgorithm
    }

    var securityPolicyUri: String {
        securitySessionState.securityPolicy.securityPolicyUri
    }

    var remoteCertificate: Data {
        securitySessionState.securityPolicy.remoteCertificate
    }

    var activeSecurityPolicy: SecurityPolicy {
        securitySessionState.securityPolicy
    }

    var policyKind: SecurityPolicies {
        securitySessionState.securityPolicy.securityPolicyUri.securityPolicy
    }

    var hasLocalCertificate: Bool {
        securitySessionState.securityPolicy.localCertificate.isEmpty == false
    }

    var isSecurityEncryptionEnabled: Bool {
        securitySessionState.securityPolicy.isEncryptionEnabled
    }

    var isSecuritySigningEnabled: Bool {
        securitySessionState.securityPolicy.isSigningEnabled
    }

    var isSecurityAsymmetric: Bool {
        securitySessionState.securityPolicy.isAsymmetric
    }

    var currentSecurityHeaderSize: Int {
        securitySessionState.securityPolicy.securityHeaderSize
    }

    var currentSecurityRemoteHeaderSize: Int {
        securitySessionState.securityPolicy.securityRemoteHeaderSize
    }

    var currentRemoteAsymmetricSignatureSize: Int {
        securitySessionState.securityPolicy.remoteAsymmetricSignatureSize
    }

    var currentAsymmetricSignatureSize: Int {
        securitySessionState.securityPolicy.asymmetricSignatureSize
    }

    var currentAsymmetricCipherTextBlockSize: Int {
        securitySessionState.securityPolicy.asymmetricCipherTextBlockSize
    }

    var currentAsymmetricPlainTextBlockSize: Int {
        securitySessionState.securityPolicy.asymmetricPlainTextBlockSize
    }

    var currentSymmetricSignatureSize: Int {
        securitySessionState.securityPolicy.symmetricSignatureSize
    }

    // Some servers require encrypted secure-channel traffic when Sign mode is used
    // with a non-null receiver certificate thumbprint in OPN.
    var useSignThumbprintCompatibilityEncryption: Bool {
        messageSecurityMode == .sign && includeServerThumbprintInOpn && hasRemoteCertificate
    }

    var effectiveOpenSecureChannelMode: MessageSecurityMode {
        if isAcknowledgeSecure {
            return .none
        }
        if useSignThumbprintCompatibilityEncryption {
            return .signAndEncrypt
        }
        return messageSecurityMode
    }
    
    init(
        cryptoContext: RSACrypto.RuntimeContext = RSACrypto.RuntimeContext(),
        securityPolicy: SecurityPolicy = SecurityPolicy(),
        messageSecurityMode: MessageSecurityMode = .none,
        bufferSize: Int = 8196,
        includeServerThumbprintInOpn: Bool = false,
        expectedServerThumbprint: Data? = nil,
        verifyReceivedSignatures: Bool = false
    ) {
        self.securitySessionState = SecuritySessionState(
            cryptoContext: cryptoContext,
            securityPolicy: securityPolicy,
            messageSecurityMode: messageSecurityMode,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn
        )
        self.protocolSessionState = ProtocolSessionState(
            messageSecurityMode: messageSecurityMode,
            bufferSize: bufferSize,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn,
            expectedServerThumbprint: expectedServerThumbprint
        )
        self.verifyReceivedSignaturesBox = NIOLockedValueBox(verifyReceivedSignatures)
    }
    
    func resetSequenceNumber() {
        protocolSessionState.resetSequenceNumber()
    }
    
    func nextSequenceNumber() -> UInt32 {
        protocolSessionState.nextSequenceNumber()
    }

    func setSecurityKeys(_ securityKeys: RSACrypto.SecurityKeys?) {
        securitySessionState.cryptoContext.setSecurityKeys(securityKeys)
    }

    func resetSecurityKeys() {
        securitySessionState.cryptoContext.resetSessionKeys()
    }

    func loadRemoteCertificate(_ data: [UInt8]) {
        securitySessionState.securityPolicy.loadRemoteCertificate(data: data)
    }

    func sign(_ data: Data) throws -> Data {
        try securitySessionState.securityPolicy.sign(data: data)
    }

    func verifySignature(_ signature: Data, data: Data) -> Bool {
        securitySessionState.securityPolicy.signVerify(signature: signature, data: data)
    }

    func encryptAsymmetric(_ data: [UInt8]) throws -> [UInt8] {
        try securitySessionState.securityPolicy.cryptAsymmetric(data: data)
    }

    func decryptAsymmetric(_ data: [UInt8]) throws -> [UInt8] {
        try securitySessionState.securityPolicy.decryptAsymmetric(data: data)
    }

    func encryptSymmetric(_ data: [UInt8]) throws -> [UInt8] {
        try securitySessionState.securityPolicy.cryptSymmetric(data: data)
    }

    func decryptSymmetric(_ data: [UInt8]) throws -> [UInt8] {
        try securitySessionState.securityPolicy.decryptSymmetric(data: data)
    }

    func replaceSecurityPolicy(uri: String) {
        securitySessionState.replaceSecurityPolicy(
            uri: uri,
            messageSecurityMode: messageSecurityMode,
            includeServerThumbprintInOpn: includeServerThumbprintInOpn
        )
    }

    func loadLocalCertificate(certificate: String?, privateKey: String?) {
        securitySessionState.securityPolicy.loadLocalCertificate(certificate: certificate, privateKey: privateKey)
    }
}
