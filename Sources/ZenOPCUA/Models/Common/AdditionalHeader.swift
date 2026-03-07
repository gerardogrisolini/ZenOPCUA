//
//  AdditionalHeader.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct AdditionalHeader: OPCUAEncodable, OPCUADecodable, Sendable {
    var nodeValue: NodeValue = .base(identifier: 0)
    var encodingMask: UInt8 = 0x00

    internal var bytes: [UInt8] {
        return nodeValue.bytes + [encodingMask]
    }
    
    init() { }

    init(bytes: [UInt8]) {
        nodeValue = .base(identifier: bytes[1])
        encodingMask = bytes[2]
    }
}
