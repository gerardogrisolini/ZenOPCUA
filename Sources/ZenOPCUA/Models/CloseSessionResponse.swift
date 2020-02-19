//
//  CloseSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class CloseSessionResponse: MessageBase, OPCUADecodable {
    let typeId: TypeId
    let responseHeader: ResponseHeader
    
    required init(bytes: [UInt8]) {
        typeId = TypeId(identifierNumeric: .closeSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init()
        secureChannelId = UInt32(littleEndianBytes: bytes[0...3])
        tokenId = UInt32(littleEndianBytes: bytes[4...7])
    }
}
