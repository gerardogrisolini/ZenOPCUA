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
}

public enum Nodes: UInt8 {
    case base = 0x00
    case numeric = 0x01
    case string = 0x03
}

public class Node: OPCUAEncodable {
    public var encodingMask: Nodes
    var bytes: [UInt8] { return [] }

    init(_ encodingMask: Nodes) {
        self.encodingMask = encodingMask
    }
}

public class NodeId: Node {
    public var identifierNumeric: UInt8 = 0x00

    init() {
        super.init(.base)
    }
    
    init(identifierNumeric: UInt8) {
        self.identifierNumeric = identifierNumeric
        super.init(.base)
    }

    override var bytes: [UInt8] {
         return [encodingMask.rawValue, identifierNumeric]
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

    init(identifier: String) {
        self.identifier = identifier
        super.init(.string)
    }
    
    override var bytes: [UInt8] {
        return [encodingMask.rawValue] + nameSpace.bytes + identifier.bytes
    }
}
