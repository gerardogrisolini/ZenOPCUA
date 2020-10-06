//
//  OpenSecureChannelResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannelResponse: MessageBase, OPCUADecodable {
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

        secureChannelId = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        var len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        securityPolicyUri = String(bytes: bytes[index..<index+len.int], encoding: .utf8)!
        index += len.int

        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max {
            senderCertificate.append(contentsOf: bytes[index..<index+len.int])
            index += len.int
        }
        
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max {
            receiverCertificateThumbprint.append(contentsOf: bytes[index..<index+len.int])
            index += len.int
        }
        
        sequenceNumber = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        requestId = UInt32(bytes: bytes[index..<index+4])
        index += 4

        typeId = NodeIdNumeric(method: .openSecureChannelResponse)
        index += 4

        responseHeader = ResponseHeader(bytes: bytes[index..<index+24].map { $0 })
        index += 24
        
        serverProtocolVersion = UInt32(bytes: bytes[index..<index+4])
        index += 4
        
        securityToken = SecurityToken(bytes: bytes[index..<index+20].map { $0 })
        index += 20
        tokenId = securityToken.tokenId
        print(securityToken)
        
        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max {
            serverNonce.append(contentsOf: bytes[index..<index+len.int])
        }
    }
}
