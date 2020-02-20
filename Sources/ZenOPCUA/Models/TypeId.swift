//
//  TypeId.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

public struct TypeId: OPCUAEncodable {
    public var encodingMask: UInt8 = 0x01
    public var nameSpace: UInt8 = 0
    public var identifierNumeric: UInt16

    init(nameSpace: UInt8, identifierNumeric: UInt16) {
        self.nameSpace = nameSpace
        self.identifierNumeric = identifierNumeric
    }

    init(identifierNumeric: Nodes) {
        self.identifierNumeric = identifierNumeric.rawValue
    }
    
    var bytes: [UInt8] {
        return [encodingMask, nameSpace] + identifierNumeric.bytes
    }
}
