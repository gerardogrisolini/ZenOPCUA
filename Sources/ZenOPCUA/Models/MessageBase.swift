//
//  MessageBase.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class MessageBase {
    var secureChannelId: UInt32 = 0
    var tokenId: UInt32 = 0
    var sequenceNumber: UInt32 = 0
    var requestId: UInt32 = 0
    
    init() {
    }
    
    init(bytes: [UInt8]) {
        guard bytes.count == 16 else { return }
        secureChannelId = UInt32(bytes: bytes[0...3])
        tokenId = UInt32(bytes: bytes[4...7])
        sequenceNumber = UInt32(bytes: bytes[8...11])
        requestId = UInt32(bytes: bytes[12...15])
    }
}
