//
//  CloseSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class CloseSessionResponse: MessageBase {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .closeSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })
        secureChannelId = UInt32(littleEndianBytes: bytes[0...3])
        tokenId = UInt32(littleEndianBytes: bytes[4...7])
    }
}
