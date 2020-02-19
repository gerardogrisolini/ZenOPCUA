//
//  SecurityToken.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct SecurityToken: OPCUADecodable {
    var channelId: UInt32
    var tokenId: UInt32
    var createdAt: UInt64
    var revisedLifetime: UInt32
    
    init(bytes: [UInt8]) {
        channelId = UInt32(littleEndianBytes: bytes[0...3])
        tokenId = UInt32(littleEndianBytes: bytes[4...7])
        createdAt = UInt64(littleEndianBytes: bytes[8...15])
        revisedLifetime = UInt32(littleEndianBytes: bytes[16...19])
    }
}
