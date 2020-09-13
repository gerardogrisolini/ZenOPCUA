//
//  ReadRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

public enum TimestampsToReturn: UInt32 {
    case source = 0
    case server = 1
    case both = 2
    case neither = 3
}

class ReadRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .readRequest)
    let requestHeader: RequestHeader
    let maxAge: Double = 0
    let timestampsToReturn: TimestampsToReturn = .source
    let nodesToRead: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        nodesToRead: [ReadValue]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.nodesToRead = UInt32(nodesToRead.count).bytes + nodesToRead.map { $0.bytes }.reduce([], +)
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }

    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            maxAge.bytes +
            timestampsToReturn.rawValue.bytes +
            nodesToRead
    }
}

public struct ReadValue: OPCUAEncodable {
    let nodeId: Node
    let attributeId: UInt32
    var indexRange: String? = nil
    let dataEncoding: QualifiedName
    
    public init(
        nodeId: Node,
        attributeId: UInt32 = 0x0000000d,
        dataEncoding: QualifiedName = QualifiedName()
    ) {
        self.nodeId = nodeId
        self.attributeId = attributeId
        self.dataEncoding = dataEncoding
    }
    
    internal var bytes: [UInt8] {
        return nodeId.bytes +
            attributeId.bytes +
            indexRange.bytes +
            dataEncoding.bytes
    }
}
