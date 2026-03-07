//
//  GetEndpointsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct GetEndpointsResponse: OPCUADecodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let endpoints: [EndpointDescription]

    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .getEndpointsResponse)
        if bytes.count >= 44 {
            let part = bytes[20...43].map { $0 }
            responseHeader = ResponseHeader(bytes: part)
        } else {
            responseHeader = ResponseHeader(bytes: [UInt8](repeating: 0, count: 24))
        }
        header = MessageHeader(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])

        var index = 44
        var parsedEndpoints: [EndpointDescription] = []

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
            guard let data = readByteStringSafe() else { return nil }
            return String(decoding: data, as: UTF8.self)
        }

        guard let count = readUInt32Safe(), count < UInt32.max else {
            endpoints = parsedEndpoints
            return
        }
        for _ in 0..<count {
            var item = EndpointDescription()
            item.endpointUrl = readStringSafe() ?? ""
            item.server.applicationUri = readStringSafe() ?? ""
            item.server.productUri = readStringSafe() ?? ""

            item.server.applicationName.encodingMask = readByteSafe() ?? 0
            if item.server.applicationName.encodingMask == 0x03 {
                item.server.applicationName.locale = readStringSafe() ?? ""
            }
            item.server.applicationName.text = readStringSafe() ?? ""

            if let rawType = readUInt32Safe(), let applicationType = ApplicationType(rawValue: rawType) {
                item.server.applicationType = applicationType
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

                    if let rawTokenType = readUInt32Safe(), let tokenType = UserTokenType(rawValue: rawTokenType) {
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

            parsedEndpoints.append(item)
        }
        endpoints = parsedEndpoints
    }
}
