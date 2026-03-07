//
//  OpenSecureChannelResponse.swift
//
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct OpenSecureChannelResponse: OPCUADecodable, Sendable {
    private struct ParsedHeader {
        let secureChannelId: UInt32
        let tokenId: UInt32
        let sequenceNumber: UInt32
        let requestId: UInt32
        let nextIndex: Int
    }

    let header: MessageHeader
    let securityPolicyUri: String?
    let senderCertificate: [UInt8]
    let receiverCertificateThumbprint: [UInt8]
    let typeId: NodeValue
    let responseHeader: ResponseHeader?
    let serverProtocolVersion: UInt32?
    let securityToken: SecurityToken?
    let serverNonce: [UInt8]

    private static func parseHeader(bytes: [UInt8]) -> ParsedHeader? {
        var index = 0

        guard bytes.count >= 4 else { return nil }
        let secureChannelId = UInt32(bytes: bytes[index..<index+4])
        index += 4

        guard bytes.count >= index + 4 else { return nil }
        var len = UInt32(bytes: bytes[index..<index+4])
        index += 4

        guard bytes.count >= index + len.int else { return nil }
        index += len.int

        guard bytes.count >= index + 4 else { return nil }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max {
            guard bytes.count >= index + len.int else { return nil }
            index += len.int
        }

        guard bytes.count >= index + 4 else { return nil }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max {
            guard bytes.count >= index + len.int else { return nil }
            index += len.int
        }

        guard bytes.count >= index + 4 else { return nil }
        let sequenceNumber = UInt32(bytes: bytes[index..<index+4])
        index += 4

        guard bytes.count >= index + 4 else { return nil }
        let requestId = UInt32(bytes: bytes[index..<index+4])
        index += 4

        let typeIdIndex = index
        index = typeIdIndex + 4

        guard bytes.count >= index + 24 else { return nil }
        index += 24

        guard bytes.count >= index + 4 else { return nil }
        index += 4

        guard bytes.count >= index + 20 else { return nil }
        let tokenId = UInt32(bytes: bytes[index + 4...index + 7])

        return ParsedHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            sequenceNumber: sequenceNumber,
            requestId: requestId,
            nextIndex: typeIdIndex
        )
    }

    init(bytes: [UInt8]) {
        let parsedHeader = Self.parseHeader(bytes: bytes)
        header = MessageHeader(
            secureChannelId: parsedHeader?.secureChannelId ?? 0,
            tokenId: parsedHeader?.tokenId ?? 0,
            sequenceNumber: parsedHeader?.sequenceNumber ?? 0,
            requestId: parsedHeader?.requestId ?? 0
        )
        typeId = NodeValue(method: .openSecureChannelResponse)

        guard let parsedHeader else {
            securityPolicyUri = nil
            senderCertificate = []
            receiverCertificateThumbprint = []
            responseHeader = nil
            serverProtocolVersion = nil
            securityToken = nil
            serverNonce = []
            return
        }

        var index = 4
        var parsedSecurityPolicyUri: String?
        var parsedSenderCertificate: [UInt8] = []
        var parsedReceiverCertificateThumbprint: [UInt8] = []
        var parsedResponseHeader: ResponseHeader?
        var parsedServerProtocolVersion: UInt32?
        var parsedSecurityToken: SecurityToken?
        var parsedServerNonce: [UInt8] = []

        var len = UInt32(bytes: bytes[index..<index+4])
        index += 4

        guard let policy = String(bytes: bytes[index..<index+len.int], encoding: .utf8) else {
            securityPolicyUri = nil
            senderCertificate = []
            receiverCertificateThumbprint = []
            responseHeader = nil
            serverProtocolVersion = nil
            securityToken = nil
            serverNonce = []
            return
        }
        parsedSecurityPolicyUri = policy
        index += len.int

        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max && bytes.count >= index + len.int {
            parsedSenderCertificate.append(contentsOf: bytes[index..<index+len.int])
            index += len.int
        }
        
        guard bytes.count >= index + 4 else {
            securityPolicyUri = parsedSecurityPolicyUri
            senderCertificate = parsedSenderCertificate
            receiverCertificateThumbprint = []
            responseHeader = nil
            serverProtocolVersion = nil
            securityToken = nil
            serverNonce = []
            return
        }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max && bytes.count >= index + len.int {
            parsedReceiverCertificateThumbprint.append(contentsOf: bytes[index..<index+len.int])
            index += len.int
        }

        index = parsedHeader.nextIndex + 4

        guard bytes.count >= index + 24 else {
            securityPolicyUri = parsedSecurityPolicyUri
            senderCertificate = parsedSenderCertificate
            receiverCertificateThumbprint = parsedReceiverCertificateThumbprint
            responseHeader = nil
            serverProtocolVersion = nil
            securityToken = nil
            serverNonce = []
            return
        }
        parsedResponseHeader = ResponseHeader(bytes: bytes[index..<index+24].map { $0 })
        index += 24
        
        guard bytes.count >= index + 4 else {
            securityPolicyUri = parsedSecurityPolicyUri
            senderCertificate = parsedSenderCertificate
            receiverCertificateThumbprint = parsedReceiverCertificateThumbprint
            responseHeader = parsedResponseHeader
            serverProtocolVersion = nil
            securityToken = nil
            serverNonce = []
            return
        }
        parsedServerProtocolVersion = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        guard bytes.count >= index + 20 else {
            securityPolicyUri = parsedSecurityPolicyUri
            senderCertificate = parsedSenderCertificate
            receiverCertificateThumbprint = parsedReceiverCertificateThumbprint
            responseHeader = parsedResponseHeader
            serverProtocolVersion = parsedServerProtocolVersion
            securityToken = nil
            serverNonce = []
            return
        }
        parsedSecurityToken = SecurityToken(bytes: bytes[index..<index+20].map { $0 })
        index += 20
        
        guard bytes.count >= index + 4 else {
            securityPolicyUri = parsedSecurityPolicyUri
            senderCertificate = parsedSenderCertificate
            receiverCertificateThumbprint = parsedReceiverCertificateThumbprint
            responseHeader = parsedResponseHeader
            serverProtocolVersion = parsedServerProtocolVersion
            securityToken = parsedSecurityToken
            serverNonce = []
            return
        }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max && bytes.count >= index + len.int {
            parsedServerNonce.append(contentsOf: bytes[index..<index+len.int])
        }

        securityPolicyUri = parsedSecurityPolicyUri
        senderCertificate = parsedSenderCertificate
        receiverCertificateThumbprint = parsedReceiverCertificateThumbprint
        responseHeader = parsedResponseHeader
        serverProtocolVersion = parsedServerProtocolVersion
        securityToken = parsedSecurityToken
        serverNonce = parsedServerNonce
    }
}
