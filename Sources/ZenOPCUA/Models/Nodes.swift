//
//  Nodes.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

public enum Methods: UInt16 {
    case userIdentityToken = 321
    case openSecureChannelRequest = 446
    case openSecureChannelResponse = 449
    case getEndpointsRequest = 428
    case getEndpointsResponse = 431
    case createSessionRequest = 461
    case createSessionResponse = 464
    case activateSessionRequest = 467
    case activateSessionResponse = 470
    case closeSessionRequest = 473
    case closeSessionResponse = 476
    case closeSecureChannelRequest = 452
    case browseRequest = 527
    case browseResponse = 530
    case readRequest = 631
    case readResponse = 634
    case writeRequest = 673
    case writeResponse = 676
    case createSubscriptionRequest = 787
    case createSubscriptionResponse = 790
    case deleteSubscriptionsRequest = 847
    case deleteSubscriptionsResponse = 850
    case createMonitoredItemsRequest = 751
    case createMonitoredItemsResponse = 754
    case publishRequest = 826
    case publishResponse = 829
}

public enum Nodes: UInt8 {
    case base = 0x00
    case numeric = 0x01
    case string = 0x03
    case guid = 0x04
    case byteString = 0x05

    case baseExt = 0x40
    case numericExt = 0x41
    case stringExt = 0x43
}

public class Node: OPCUAEncodable {
    public var encodingMask: Nodes
    var bytes: [UInt8] { return [] }

    init(_ encodingMask: Nodes) {
        self.encodingMask = encodingMask
    }
}

public class NodeId: Node {
    public var identifier: UInt8 = 0x00

    init() {
        super.init(.base)
    }
    
    public init(identifier: UInt8) {
        self.identifier = identifier
        super.init(.base)
    }

    override var bytes: [UInt8] {
         return [encodingMask.rawValue, identifier]
     }
}

public class NodeIdNumeric: Node {
    public var nameSpace: UInt8 = 0
    public var identifier: UInt16

    init(nameSpace: UInt8, identifier: UInt16) {
        self.nameSpace = nameSpace
        self.identifier = identifier
        super.init(.numeric)
    }

    init(method: Methods) {
        self.identifier = method.rawValue
        super.init(.numeric)
    }
    
    override var bytes: [UInt8] {
        return [encodingMask.rawValue, nameSpace] + identifier.bytes
    }
}

public class NodeIdString: Node {
    public var nameSpace: UInt16 = 1
    public var identifier: String

    init(nameSpace: UInt16, identifier: String) {
        self.nameSpace = nameSpace
        self.identifier = identifier
        super.init(.string)
    }

    override var bytes: [UInt8] {
        return [encodingMask.rawValue] + nameSpace.bytes + identifier.bytes
    }
}

public class NodeIdGuid: Node {
    public var nameSpace: UInt16 = 1
    public var identifier: [UInt8]

    init(nameSpace: UInt16, identifier: [UInt8]) {
        self.nameSpace = nameSpace
        self.identifier = identifier
        super.init(.guid)
    }
    
    override var bytes: [UInt8] {
        return [encodingMask.rawValue] + nameSpace.bytes + identifier
    }
}

public class NodeIdByteString: Node {
    public var nameSpace: UInt16 = 1
    public var identifier: [UInt8]

    init(nameSpace: UInt16, identifier: [UInt8]) {
        self.nameSpace = nameSpace
        self.identifier = identifier
        super.init(.byteString)
    }
    
    override var bytes: [UInt8] {
        let len = UInt32(identifier.count).bytes
        return [encodingMask.rawValue] + nameSpace.bytes + len + identifier
    }
}

public class NodeIdExt: Node {
    public let identifier: UInt8
    public let serverIndex: UInt32

    init(identifier: UInt8, serverIndex: UInt32) {
        self.identifier = identifier
        self.serverIndex = serverIndex
        super.init(.baseExt)
    }

    override var bytes: [UInt8] {
        return [encodingMask.rawValue, identifier] + serverIndex.bytes
    }
}

public class NodeIdNumericExt: Node {
    public let nameSpace: UInt8
    public let identifier: UInt16
    public let serverIndex: UInt32

    init(nameSpace: UInt8, identifier: UInt16, serverIndex: UInt32) {
        self.nameSpace = nameSpace
        self.identifier = identifier
        self.serverIndex = serverIndex
        super.init(.numericExt)
    }

    override var bytes: [UInt8] {
        return [encodingMask.rawValue, nameSpace] + identifier.bytes + serverIndex.bytes
    }
}

public class NodeIdStringExt: Node {
    public let nameSpace: UInt16
    public let identifier: String
    public let serverIndex: UInt32

    init(nameSpace: UInt16, identifier: String, serverIndex: UInt32) {
        self.nameSpace = nameSpace
        self.identifier = identifier
        self.serverIndex = serverIndex
        super.init(.stringExt)
    }

    override var bytes: [UInt8] {
        return [encodingMask.rawValue] + nameSpace.bytes + identifier.bytes + serverIndex.bytes
    }
}


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
