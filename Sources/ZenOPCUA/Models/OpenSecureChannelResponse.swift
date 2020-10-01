//
//  OpenSecureChannelResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class OpenSecureChannelResponse: OpenSecureChannel, OPCUADecodable {
    var typeId: NodeIdNumeric
    var responseHeader: ResponseHeader
    var serverProtocolVersion: UInt32
    var securityToken: SecurityToken
    var serverNonce: String?

    required init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .openSecureChannelResponse)
        let part = bytes[75...98].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        serverProtocolVersion = UInt32(bytes: bytes[99...102])
        let part2 = bytes[103...122].map { $0 }
        securityToken = SecurityToken(bytes: part2)
        
        //TODO: complete parsing response
        serverNonce = nil //bytes[123...126]
        
        super.init(
            secureChannelId: UInt32(bytes: bytes[0...3]),
            securityPolicyUri: SecurityPolicies.none.uri,
            requestId: responseHeader.requestHandle
        )
    }
}
