//
//  MessageBase.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct MessageHeader: Sendable {
    let secureChannelId: UInt32
    let tokenId: UInt32
    let sequenceNumber: UInt32
    let requestId: UInt32

    init(
        secureChannelId: UInt32 = 0,
        tokenId: UInt32 = 0,
        sequenceNumber: UInt32 = 0,
        requestId: UInt32 = 0
    ) {
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }

    init(bytes: [UInt8]) {
        guard bytes.count == 16 else {
            self.init()
            return
        }
        self.init(
            secureChannelId: UInt32(bytes: bytes[0...3]),
            tokenId: UInt32(bytes: bytes[4...7]),
            sequenceNumber: UInt32(bytes: bytes[8...11]),
            requestId: UInt32(bytes: bytes[12...15])
        )
    }
}
