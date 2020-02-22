//
//  NodeSessionId.swift
//  
//
//  Created by Gerardo Grisolini on 21/02/2020.
//

struct NodeSessionId: OPCUAEncodable, OPCUADecodable {
    let encodingMask: UInt8
    let nameSpace: UInt16
    let identifier: [UInt8]

    var bytes: [UInt8] {
        return [encodingMask] +
            nameSpace.bytes +
            identifier
    }

    init(bytes: [UInt8]) {
        encodingMask = bytes[0]
        nameSpace = UInt16(littleEndianBytes: bytes[1...2])
        identifier = bytes[3...18].map { $0 }
    }
}
