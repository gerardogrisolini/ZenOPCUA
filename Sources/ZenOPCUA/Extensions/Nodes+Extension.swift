//
//  Nodes+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension Nodes {
    
    static func node(index: inout Int, bytes: [UInt8]) -> Node {
        switch Nodes(rawValue: bytes[index])! {
        case .numeric:
            let nodeId = NodeIdNumeric(
                nameSpace: bytes[index+1],
                identifier: UInt16(bytes: bytes[(index+2)..<(index+4)])
            )
            index += 4
            return nodeId
        case .string:
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            let nodeId = NodeIdString(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8)!
            )
            index += len + 7
            return nodeId
        case .guid:
            let nodeId = NodeIdGuid(
                nameSpace: UInt16(bytes: bytes[(index+1)...(index+2)]),
                identifier: bytes[(index+3)..<(index+19)].map { $0 }
            )
            index += 19
            return nodeId
        case .byteString:
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            let nodeId = NodeIdByteString(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: bytes[(index+7)..<(index+len+7)].map { $0 }
            )
            index += len + 7
            return nodeId
        case .baseExt:
            let nodeId = NodeIdExt(
                identifier: bytes[index+1],
                serverIndex: UInt32(bytes: bytes[(index+2)..<(index+6)])
            )
            index += 6
            return nodeId
        case .numericExt:
            let nodeId = NodeIdNumericExt(
                nameSpace: bytes[index+1],
                identifier: UInt16(bytes: bytes[(index+2)..<(index+4)]),
                serverIndex: UInt32(bytes: bytes[(index+4)..<(index+8)])
            )
            index += 8
            return nodeId
        case .stringExt:
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            let nodeId = NodeIdStringExt(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8)!,
                serverIndex: UInt32(bytes: bytes[(index+len+7)..<(index+len+7+4)])
            )
            index += len + 7 + 4
            return nodeId
        default:
            let nodeId = NodeId(identifier: bytes[index+1])
            index += 2
            return nodeId
        }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ node: Node) {
        switch node.encodingMask {
        case .numeric:
            let n = node as! NodeIdNumeric
            appendInterpolation("NodeIdNumeric { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
        case .string:
           let n = node as! NodeIdString
           appendInterpolation("NodeIdString { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
        case .guid:
           let n = node as! NodeIdGuid
           appendInterpolation("NodeIdGuid { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
        case .byteString:
           let n = node as! NodeIdByteString
           appendInterpolation("NodeIdByteString { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
       case .baseExt:
           let n = node as! NodeIdExt
           appendInterpolation("NodeIdExt { serverIndex = \(n.serverIndex), identifier = \(n.identifier) }")
        case .numericExt:
           let n = node as! NodeIdNumericExt
           appendInterpolation("NodeIdNumericExt { namespace: \(n.nameSpace), identifier = \(n.identifier), serverIndex = \(n.serverIndex) }")
        case .stringExt:
           let n = node as! NodeIdStringExt
           appendInterpolation("NodeIdStringExt { namespace: \(n.nameSpace), identifier = \(n.identifier), serverIndex = \(n.serverIndex) }")
        default:
           let n = node as! NodeId
           appendInterpolation("NodeId { identifier: \(n.identifier)")
        }
    }
}
