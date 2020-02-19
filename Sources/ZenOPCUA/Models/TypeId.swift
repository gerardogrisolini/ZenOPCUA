//
//  TypeId.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct TypeId: OPCUAEncodable {
    public var encodingMask: UInt8 = 0x01
    public var nameSpace: UInt8 = 0
    public var identifierNumeric: Nodes

    var bytes: [UInt8] {
        return [encodingMask, nameSpace] + identifierNumeric.rawValue.bytes
    }
}
