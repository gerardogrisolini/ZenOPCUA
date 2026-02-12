//
//  OpenSecureChannelResponse.swift
//
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannelResponse: MessageBase, OPCUADecodable, @unchecked Sendable {
    var securityPolicyUri: String!
    var senderCertificate: [UInt8] = []
    var receiverCertificateThumbprint: [UInt8] = []
    var typeId: NodeIdNumeric = NodeIdNumeric(method: .openSecureChannelResponse)
    var responseHeader: ResponseHeader!
    var serverProtocolVersion: UInt32!
    var securityToken: SecurityToken!
    var serverNonce: [UInt8] = []

    required override init(bytes: [UInt8]) {
        super.init()
        
        var index = 0
        
        guard bytes.count >= 4 else { return }

        secureChannelId = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        guard bytes.count >= index + 4 else { return }
        var len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        guard bytes.count >= index + len.int else { return }
        securityPolicyUri = String(bytes: bytes[index..<index+len.int], encoding: .utf8)!
        index += len.int

        guard bytes.count >= index + 4 else { return }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max && bytes.count >= index + len.int {
            senderCertificate.append(contentsOf: bytes[index..<index+len.int])
            index += len.int
        }
        
        guard bytes.count >= index + 4 else { return }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max && bytes.count >= index + len.int {
            receiverCertificateThumbprint.append(contentsOf: bytes[index..<index+len.int])
            index += len.int
        }
        
        guard bytes.count >= index + 4 else { return }
        sequenceNumber = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        guard bytes.count >= index + 4 else { return }
        requestId = UInt32(bytes: bytes[index..<index+4])
        index += 4

        typeId = NodeIdNumeric(method: .openSecureChannelResponse)
        index += 4

        guard bytes.count >= index + 24 else { return }
        responseHeader = ResponseHeader(bytes: bytes[index..<index+24].map { $0 })
        index += 24
        
        guard bytes.count >= index + 4 else { return }
        serverProtocolVersion = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        guard bytes.count >= index + 20 else { return }
        securityToken = SecurityToken(bytes: bytes[index..<index+20].map { $0 })
        index += 20
        tokenId = securityToken.tokenId
        
        guard bytes.count >= index + 4 else { return }
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max && bytes.count >= index + len.int {
            serverNonce.append(contentsOf: bytes[index..<index+len.int])
        }
    }
}
