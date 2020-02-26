//
//  CreateSubscriptionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

class CreateSubscriptionResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    let subscriptionId: UInt32
    let revisedPubliscingInterval: Double
    let revisedLifetimeCount: UInt32
    let revisedMaxKeepAliveCount: UInt32
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .createSubscriptionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)

        var index = 44
        subscriptionId = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        revisedPubliscingInterval = Double(bytes: bytes[index..<(index+8)].map { $0 })
        index += 8
        revisedLifetimeCount = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        revisedMaxKeepAliveCount = UInt32(littleEndianBytes: bytes[index..<(index+4)])

        super.init(bytes: bytes[0...15].map { $0 })
    }
}
