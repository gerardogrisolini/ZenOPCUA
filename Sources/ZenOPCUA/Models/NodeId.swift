//
//  NodeId.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct NodeId: OPCUAEncodable, OPCUADecodable {
    var encodingMask: UInt8 = 0x00
    var identifierNumeric: UInt8 = 0x00

    var bytes: [UInt8] {
        return [encodingMask, identifierNumeric]
    }
    
    init() { }
    
    init(bytes: [UInt8]) {
        encodingMask = bytes[0]
        identifierNumeric = bytes[1]
    }
}
