//
//  CreateSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

import Foundation

struct CreateSessionResponse: Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let sessionIdValue: NodeValue
    let authenticationTokenValue: NodeValue
    let revisedSessionTimeout: Double
    var serverNonce: [UInt8] = []
    var serverCertificate: [UInt8] = []
    var serverEndpoints: [EndpointDescription] = []
    var serverSoftwareCertificates: [[UInt8]] = []
    var serverSignature: SignatureData = SignatureData()
    var maxRequestMessageSize: UInt32 = 0
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .createSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        var index = 44
        
        sessionIdValue = NodeValue.parse(index: &index, bytes: bytes)
        authenticationTokenValue = NodeValue.parse(index: &index, bytes: bytes)

        revisedSessionTimeout = Double(bytes: bytes[index..<(index+8)].map { $0 })
        index += 8
        
        var len = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if len < UInt32.max {
            serverNonce = bytes[index..<(index+len.int)].map { $0 }
            index += len.int
        }
            
        len = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if len < UInt32.max {
            serverCertificate = bytes[index..<(index+len.int)].map { $0 }
            index += len.int
        }
        header = MessageHeader(bytes: bytes[0...15].map { $0 })

        func readUInt32Safe() -> UInt32? {
            guard index + 4 <= bytes.count else { return nil }
            let value = UInt32(bytes: bytes[index..<(index + 4)])
            index += 4
            return value
        }

        func readByteSafe() -> UInt8? {
            guard index < bytes.count else { return nil }
            let value = bytes[index]
            index += 1
            return value
        }

        func readByteStringSafe() -> [UInt8]? {
            guard let length = readUInt32Safe() else { return nil }
            if length == UInt32.max { return nil }
            let count = length.int
            guard index + count <= bytes.count else { return nil }
            let value = Array(bytes[index..<(index + count)])
            index += count
            return value
        }

        func readStringSafe() -> String? {
            guard let value = readByteStringSafe() else { return nil }
            return String(decoding: value, as: UTF8.self)
        }

        guard let endpointCount = readUInt32Safe(), endpointCount < UInt32.max else { return }

        for _ in 0..<endpointCount {
            var item = EndpointDescription()
            item.endpointUrl = readStringSafe() ?? ""
            item.server.applicationUri = readStringSafe() ?? ""
            item.server.productUri = readStringSafe() ?? ""

            item.server.applicationName.encodingMask = readByteSafe() ?? 0
            if item.server.applicationName.encodingMask == 0x03 {
                item.server.applicationName.locale = readStringSafe() ?? ""
            }
            item.server.applicationName.text = readStringSafe() ?? ""

            if let rawType = readUInt32Safe(), let appType = ApplicationType(rawValue: rawType) {
                item.server.applicationType = appType
            } else {
                item.server.applicationType = .server
            }

            item.server.gatewayServerUri = readStringSafe()
            item.server.discoveryProfileUri = readStringSafe()

            if let discoveryUrlCount = readUInt32Safe(), discoveryUrlCount < UInt32.max {
                for _ in 0..<discoveryUrlCount {
                    if let url = readStringSafe() {
                        item.server.discoveryUrls.append(url)
                    }
                }
            }

            item.serverCertificate = readByteStringSafe() ?? []

            if let rawMode = readUInt32Safe(), let mode = MessageSecurityMode(rawValue: rawMode) {
                item.messageSecurityMode = mode
            } else {
                item.messageSecurityMode = .none
            }

            item.securityPolicyUri = readStringSafe() ?? ""

            if let identityCount = readUInt32Safe(), identityCount < UInt32.max {
                for _ in 0..<identityCount {
                    var identity = UserTokenPolicy()
                    identity.policyId = readStringSafe() ?? ""
                    if let rawTokenType = readUInt32Safe(),
                       let tokenType = UserTokenType(rawValue: rawTokenType) {
                        identity.tokenType = tokenType
                    } else {
                        identity.tokenType = .anonymous
                    }
                    identity.issuedTokenType = readStringSafe()
                    identity.issuerEndpointUrl = readStringSafe()
                    identity.securityPolicyUri = readStringSafe()
                    item.userIdentityTokens.append(identity)
                }
            }

            item.transportProfileUri = readStringSafe() ?? ""
            item.securityLevel = readByteSafe() ?? 0
            serverEndpoints.append(item)
        }

        if let softwareCertCount = readUInt32Safe(), softwareCertCount < UInt32.max {
            for _ in 0..<softwareCertCount {
                serverSoftwareCertificates.append(readByteStringSafe() ?? [])
            }
        }

        serverSignature.algorithm = readStringSafe() ?? ""
        serverSignature.signature = readByteStringSafe() ?? []
        maxRequestMessageSize = readUInt32Safe() ?? 0
    }
}
