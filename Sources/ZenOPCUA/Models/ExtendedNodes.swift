//
//  ExtendedNodes.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct NodeIdNumeric: OPCUAEncodable {
    public var encodingMask: UInt8 = 0x01
    public var nameSpace: UInt8 = 0
    public var identifier: UInt16

    init(nameSpace: UInt8, identifier: UInt16) {
        self.nameSpace = nameSpace
        self.identifier = identifier
    }

    init(identifier: Nodes) {
        self.identifier = identifier.rawValue
    }
    
    var bytes: [UInt8] {
        return [encodingMask, nameSpace] + identifier.bytes
    }
}

struct NodeIdString: OPCUAEncodable {
    public var encodingMask: UInt8 = 0x03
    public var nameSpace: UInt16 = 1
    public var identifier: String

    init(nameSpace: UInt16, identifier: String) {
        self.nameSpace = nameSpace
        self.identifier = identifier
    }

    init(identifier: String) {
        self.identifier = identifier
    }
    
    var bytes: [UInt8] {
        return [encodingMask] + nameSpace.bytes + identifier.bytes
    }
}
