//
//  Nodes+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension Nodes {
    
    static func node(index: inout Int, bytes: [UInt8]) -> Node {
        func fallback() -> Node {
            if index < bytes.count {
                index = min(index + 1, bytes.count)
            }
            return NodeId(identifier: 0)
        }

        func canRead(_ count: Int) -> Bool {
            index >= 0 && count >= 0 && index + count <= bytes.count
        }

        guard canRead(1), let encoding = Nodes(rawValue: bytes[index]) else {
            return fallback()
        }

        switch encoding {
        case .numeric:
            guard canRead(4) else { return fallback() }
            let nodeId = NodeIdNumeric(
                nameSpace: bytes[index+1],
                identifier: UInt16(bytes: bytes[(index+2)..<(index+4)])
            )
            index += 4
            return nodeId
        case .long:
            guard canRead(7) else { return fallback() }
            let nodeId = NodeIdLong(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: UInt32(bytes: bytes[(index+3)..<(index+7)])
            )
            index += 7
            return nodeId
        case .string:
            guard canRead(7) else { return fallback() }
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            guard len >= 0, canRead(7 + len) else { return fallback() }
            let nodeId = NodeIdString(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8) ?? ""
            )
            index += len + 7
            return nodeId
        case .guid:
            guard canRead(19) else { return fallback() }
            let nodeId = NodeIdGuid(
                nameSpace: UInt16(bytes: bytes[(index+1)...(index+2)]),
                identifier: bytes[(index+3)..<(index+19)].map { $0 }
            )
            index += 19
            return nodeId
        case .byteString:
            guard canRead(7) else { return fallback() }
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            guard len >= 0, canRead(7 + len) else { return fallback() }
            let nodeId = NodeIdByteString(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: bytes[(index+7)..<(index+len+7)].map { $0 }
            )
            index += len + 7
            return nodeId
        case .baseExt:
            guard canRead(6) else { return fallback() }
            let nodeId = NodeIdExt(
                identifier: bytes[index+1],
                serverIndex: UInt32(bytes: bytes[(index+2)..<(index+6)])
            )
            index += 6
            return nodeId
        case .numericExt:
            guard canRead(8) else { return fallback() }
            let nodeId = NodeIdNumericExt(
                nameSpace: bytes[index+1],
                identifier: UInt16(bytes: bytes[(index+2)..<(index+4)]),
                serverIndex: UInt32(bytes: bytes[(index+4)..<(index+8)])
            )
            index += 8
            return nodeId
        case .stringExt:
            guard canRead(7) else { return fallback() }
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            guard len >= 0, canRead(7 + len + 4) else { return fallback() }
            let nodeId = NodeIdStringExt(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8) ?? "",
                serverIndex: UInt32(bytes: bytes[(index+len+7)..<(index+len+7+4)])
            )
            index += len + 7 + 4
            return nodeId
        default:
            guard canRead(2) else { return fallback() }
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
            if let n = node as? NodeIdNumeric {
                appendInterpolation("NodeIdNumeric { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
            } else {
                appendInterpolation("Node(invalid numeric)")
            }
        case .string:
           if let n = node as? NodeIdString {
               appendInterpolation("NodeIdString { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
           } else {
               appendInterpolation("Node(invalid string)")
           }
        case .guid:
           if let n = node as? NodeIdGuid {
               appendInterpolation("NodeIdGuid { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
           } else {
               appendInterpolation("Node(invalid guid)")
           }
        case .byteString:
           if let n = node as? NodeIdByteString {
               appendInterpolation("NodeIdByteString { nameSpace = \(n.nameSpace), identifier = \(n.identifier) }")
           } else {
               appendInterpolation("Node(invalid byteString)")
           }
       case .baseExt:
           if let n = node as? NodeIdExt {
               appendInterpolation("NodeIdExt { serverIndex = \(n.serverIndex), identifier = \(n.identifier) }")
           } else {
               appendInterpolation("Node(invalid baseExt)")
           }
        case .numericExt:
           if let n = node as? NodeIdNumericExt {
               appendInterpolation("NodeIdNumericExt { namespace: \(n.nameSpace), identifier = \(n.identifier), serverIndex = \(n.serverIndex) }")
           } else {
               appendInterpolation("Node(invalid numericExt)")
           }
        case .stringExt:
           if let n = node as? NodeIdStringExt {
               appendInterpolation("NodeIdStringExt { namespace: \(n.nameSpace), identifier = \(n.identifier), serverIndex = \(n.serverIndex) }")
           } else {
               appendInterpolation("Node(invalid stringExt)")
           }
        default:
           if let n = node as? NodeId {
               appendInterpolation("NodeId { identifier: \(n.identifier)")
           } else {
               appendInterpolation("Node(unknown)")
           }
        }
    }
}
