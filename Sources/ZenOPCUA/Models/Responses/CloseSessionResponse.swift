//
//  CloseSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

struct CloseSessionResponse: Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .closeSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        header = MessageHeader(bytes: bytes[0...15].map { $0 })
    }
}
