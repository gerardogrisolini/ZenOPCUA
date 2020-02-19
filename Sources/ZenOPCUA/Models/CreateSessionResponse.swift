//
//  CreateSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

class CreateSessionResponse: MessageBase, OPCUADecodable {
    let typeId: TypeId
    let responseHeader: ResponseHeader
    let sessionId: SessionId
    let authenticationToken: NodeId
    let revisedSessionTimeout: UInt64
    var serverNonce: String? = nil
    var serverCertificate: String? = nil
    let serverEndpoints: [EndpointDescription] = []
    let serverSoftwareCertificates: String? = nil
    let serverSignature: SignatureData = SignatureData()
    let maxRequestMessageSize: UInt32 = 0
    
    required init(bytes: [UInt8]) {
        typeId = TypeId(identifierNumeric: .createSessionResponse)
        let part = bytes[4...27].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        let part2 = bytes[28...31].map { $0 }
        sessionId = SessionId(bytes: part2)
        let part3 = bytes[32...33].map { $0 }
        authenticationToken = NodeId(bytes: part3)
        revisedSessionTimeout = UInt64(littleEndianBytes: bytes[34...41])
        super.init()
        secureChannelId = UInt32(littleEndianBytes: bytes[0...3])
        tokenId = UInt32(littleEndianBytes: bytes[4...7])

        //TODO: serverEndpoints
    }
}

struct SessionId: OPCUADecodable {
    let encodingMask: UInt8
    let nameSpace: UInt8
    let identifierNumeric: UInt16

    init(bytes: [UInt8]) {
        encodingMask = bytes[0]
        nameSpace = bytes[1]
        identifierNumeric = UInt16(littleEndianBytes: bytes[2...3])
    }
}

struct SignatureData: OPCUAEncodable {
    let algorithm: String? = nil
    let signature: String? = nil

    var bytes: [UInt8] {
        return algorithm.bytes + signature.bytes
    }
}
