//
//  Acknowledge.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class Handshake {
    var version: UInt32 = 0
    var receiveBufferSize: UInt32 = 65535
    var sendBufferSize: UInt32 = 65535
    var maxMessageSize: UInt32 = 0
    var maxChunkCount: UInt32 = 0

    init() { }
}

class Acknowledge: Handshake, OPCUADecodable {
    required init(bytes: [UInt8]) {
        super.init()
        version = UInt32(bytes: bytes[0..<4])
        receiveBufferSize = UInt32(bytes: bytes[4..<8])
        sendBufferSize = UInt32(bytes: bytes[8..<12])
        maxMessageSize = UInt32(bytes: bytes[12..<16])
        maxChunkCount = UInt32(bytes: bytes[16..<20])
    }
}

class Hello: Handshake, OPCUAEncodable {
    let endpointUrl: String
    
    init(endpointUrl: String) {
        self.endpointUrl = endpointUrl
        super.init()
    }
    
    internal var bytes: [UInt8] {
        version.bytes +
        receiveBufferSize.bytes +
        sendBufferSize.bytes +
        maxMessageSize.bytes +
        maxChunkCount.bytes +
        endpointUrl.bytes
    }
}
