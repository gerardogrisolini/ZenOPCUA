//
//  Nodes.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

public enum Methods: UInt16 {
    case anonymousIdentityToken = 321
    case userNameIdentityToken = 324
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
    internal var bytes: [UInt8] { return [] }

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
