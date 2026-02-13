import Foundation

// Concurrency: confined to the channel's EventLoop.
final class OPCUAConnectionState: @unchecked Sendable {
    let cryptoContext: RSACrypto.RuntimeContext
    var securityPolicy: SecurityPolicy
    var messageSecurityMode: MessageSecurityMode
    var bufferSize: Int
    var isAcknowledge: Bool
    var isUpgradingToSecure: Bool
    var hasRemoteCertificate: Bool
    var isFirstConnection: Bool
    var hasSymmetricKeys: Bool
    var includeServerThumbprintInOpn: Bool
    var expectedServerThumbprint: Data?
    var opnThumbprintRetryDone: Bool
    var sequenceNumber = UInt32(1)
    var reconnect: Bool = false
    
    var isAcknowledgeSecure: Bool {
        messageSecurityMode != .none && securityPolicy.remoteCertificate.count == 0
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
        isAcknowledge: Bool = false,
        isUpgradingToSecure: Bool = false,
        hasRemoteCertificate: Bool = false,
        isFirstConnection: Bool = true,
        hasSymmetricKeys: Bool = false,
        includeServerThumbprintInOpn: Bool = false,
        expectedServerThumbprint: Data? = nil,
        opnThumbprintRetryDone: Bool = false
    ) {
        self.cryptoContext = cryptoContext
        self.securityPolicy = securityPolicy
        self.messageSecurityMode = messageSecurityMode
        self.bufferSize = bufferSize
        self.isAcknowledge = isAcknowledge
        self.isUpgradingToSecure = isUpgradingToSecure
        self.hasRemoteCertificate = hasRemoteCertificate
        self.isFirstConnection = isFirstConnection
        self.hasSymmetricKeys = hasSymmetricKeys
        self.includeServerThumbprintInOpn = includeServerThumbprintInOpn
        self.expectedServerThumbprint = expectedServerThumbprint
        self.opnThumbprintRetryDone = opnThumbprintRetryDone
        self.securityPolicy.connectionState = self
    }
    
    func resetSequenceNumber() {
        sequenceNumber = 0
    }
    
    func nextSequenceNumber() -> UInt32 {
        sequenceNumber += 1
        return sequenceNumber
    }
}
