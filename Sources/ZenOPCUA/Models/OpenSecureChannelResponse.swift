//
//  OpenSecureChannelResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannelResponse: OPCUADecodable {
    let secureChannelId: UInt32
    let securityPolicyUri: String
    var senderCertificate: [UInt8] = []
    var receiverCertificateThumbprint: [UInt8] = []
    let sequenseNumber: UInt32
    let requestId: UInt32
    var typeId: NodeIdNumeric
    var responseHeader: ResponseHeader
    var serverProtocolVersion: UInt32
    var securityToken: SecurityToken
    var serverNonce: [UInt8] = []

    required init(bytes: [UInt8]) {
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
        
        sequenseNumber = UInt32(bytes: bytes[index..<index+4])
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

        len = UInt32(bytes: bytes[index..<index+4])
        index += 4
        if len < UInt32.max {
            serverNonce.append(contentsOf: bytes[index..<index+len.int])
        }
    }
}
