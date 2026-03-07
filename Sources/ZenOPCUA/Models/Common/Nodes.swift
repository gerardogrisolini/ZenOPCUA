//
//  Nodes.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

public enum Methods: UInt16, Sendable {
    case serviceFault = 397
    case anonymousIdentityToken = 321
    case userNameIdentityToken = 324
    case certificateIdentityToken = 327
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

public enum Nodes: UInt8, Sendable {
    case base = 0x00
    case numeric = 0x01
    case long = 0x02
    case string = 0x03
    case guid = 0x04
    case byteString = 0x05

    case baseExt = 0x40
    case numericExt = 0x41
    case stringExt = 0x43
}

public enum NodeValue: Sendable, OPCUAEncodable {
    case base(identifier: UInt8)
    case compact(encoding: Nodes, identifier: UInt8)
    case numeric(nameSpace: UInt8, identifier: UInt16)
    case long(nameSpace: UInt16, identifier: UInt32)
    case string(nameSpace: UInt16, identifier: String)
    case guid(nameSpace: UInt16, identifier: [UInt8])
    case byteString(nameSpace: UInt16, identifier: [UInt8])
    case baseExt(identifier: UInt8, serverIndex: UInt32)
    case numericExt(nameSpace: UInt8, identifier: UInt16, serverIndex: UInt32)
    case stringExt(nameSpace: UInt16, identifier: String, serverIndex: UInt32)

    public init(method: Methods) {
        self = .numeric(nameSpace: 0, identifier: method.rawValue)
    }

    internal var bytes: [UInt8] {
        switch self {
        case .base(let identifier):
            return [Nodes.base.rawValue, identifier]
        case .compact(let encoding, let identifier):
            return [encoding.rawValue, identifier]
        case .numeric(let nameSpace, let identifier):
            return [Nodes.numeric.rawValue, nameSpace] + identifier.bytes
        case .long(let nameSpace, let identifier):
            return [Nodes.long.rawValue] + nameSpace.bytes + identifier.bytes
        case .string(let nameSpace, let identifier):
            return [Nodes.string.rawValue] + nameSpace.bytes + identifier.bytes
        case .guid(let nameSpace, let identifier):
            return [Nodes.guid.rawValue] + nameSpace.bytes + identifier
        case .byteString(let nameSpace, let identifier):
            return [Nodes.byteString.rawValue] + nameSpace.bytes + UInt32(identifier.count).bytes + identifier
        case .baseExt(let identifier, let serverIndex):
            return [Nodes.baseExt.rawValue, identifier] + serverIndex.bytes
        case .numericExt(let nameSpace, let identifier, let serverIndex):
            return [Nodes.numericExt.rawValue, nameSpace] + identifier.bytes + serverIndex.bytes
        case .stringExt(let nameSpace, let identifier, let serverIndex):
            return [Nodes.stringExt.rawValue] + nameSpace.bytes + identifier.bytes + serverIndex.bytes
        }
    }

    static func parse(index: inout Int, bytes: [UInt8]) -> NodeValue {
        func fallback() -> NodeValue {
            if index < bytes.count {
                index = min(index + 1, bytes.count)
            }
            return .base(identifier: 0)
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
            let value = NodeValue.numeric(
                nameSpace: bytes[index+1],
                identifier: UInt16(bytes: bytes[(index+2)..<(index+4)])
            )
            index += 4
            return value
        case .long:
            guard canRead(7) else { return fallback() }
            let value = NodeValue.long(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: UInt32(bytes: bytes[(index+3)..<(index+7)])
            )
            index += 7
            return value
        case .string:
            guard canRead(7) else { return fallback() }
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            guard len >= 0, canRead(7 + len) else { return fallback() }
            let value = NodeValue.string(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8) ?? ""
            )
            index += len + 7
            return value
        case .guid:
            guard canRead(19) else { return fallback() }
            let value = NodeValue.guid(
                nameSpace: UInt16(bytes: bytes[(index+1)...(index+2)]),
                identifier: bytes[(index+3)..<(index+19)].map { $0 }
            )
            index += 19
            return value
        case .byteString:
            guard canRead(7) else { return fallback() }
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            guard len >= 0, canRead(7 + len) else { return fallback() }
            let value = NodeValue.byteString(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: bytes[(index+7)..<(index+len+7)].map { $0 }
            )
            index += len + 7
            return value
        case .baseExt:
            guard canRead(6) else { return fallback() }
            let value = NodeValue.baseExt(
                identifier: bytes[index+1],
                serverIndex: UInt32(bytes: bytes[(index+2)..<(index+6)])
            )
            index += 6
            return value
        case .numericExt:
            guard canRead(8) else { return fallback() }
            let value = NodeValue.numericExt(
                nameSpace: bytes[index+1],
                identifier: UInt16(bytes: bytes[(index+2)..<(index+4)]),
                serverIndex: UInt32(bytes: bytes[(index+4)..<(index+8)])
            )
            index += 8
            return value
        case .stringExt:
            guard canRead(7) else { return fallback() }
            let len = Int(UInt32(bytes: bytes[(index+3)..<(index+7)]))
            guard len >= 0, canRead(7 + len + 4) else { return fallback() }
            let value = NodeValue.stringExt(
                nameSpace: UInt16(bytes: bytes[(index+1)..<(index+3)]),
                identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8) ?? "",
                serverIndex: UInt32(bytes: bytes[(index+len+7)..<(index+len+7+4)])
            )
            index += len + 7 + 4
            return value
        default:
            guard canRead(2) else { return fallback() }
            let value = encoding == .base
                ? NodeValue.base(identifier: bytes[index+1])
                : NodeValue.compact(encoding: encoding, identifier: bytes[index+1])
            index += 2
            return value
        }
    }
}
