//
//  AdditionalHeader.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct AdditionalHeader: OPCUAEncodable, OPCUADecodable {
    var nodeId: NodeId = NodeId()
    var encodingMask: UInt8 = 0x00

    var bytes: [UInt8] {
        return nodeId.bytes + [encodingMask]
    }
    
    init() { }

    init(bytes: [UInt8]) {
        nodeId = NodeId(bytes: bytes)
        encodingMask = bytes[2]
    }
}
