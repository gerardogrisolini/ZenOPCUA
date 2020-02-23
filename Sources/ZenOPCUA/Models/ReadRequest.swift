//
//  ReadRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class ReadRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .readRequest)
    let requestHeader: RequestHeader
    let maxAge: Double = 0
    let timestampsToReturn: UInt32 = 0x00000000
    let nodesToRead: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: NodeSessionId,
        nodesToRead: [ReadValueId]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.nodesToRead = UInt32(nodesToRead.count).bytes + nodesToRead.map { $0.bytes }.reduce([], +)
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }

    var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            maxAge.bytes +
            timestampsToReturn.bytes +
            nodesToRead
    }
}

public struct ReadValueId: OPCUAEncodable {
    private let nodeId: Node
    private let attributeId: UInt32
    private var indexRange: String? = nil
    private let dataEncoding: QualifiedName
    
    init(
        nodeId: Node,
        attributeId: UInt32 = 0x0000000d,
        dataEncoding: QualifiedName = QualifiedName()
    ) {
        self.nodeId = nodeId
        self.attributeId = attributeId
        self.dataEncoding = dataEncoding
    }
    
    var bytes: [UInt8] {
        return nodeId.bytes +
            attributeId.bytes +
            indexRange.bytes +
            dataEncoding.bytes
    }
}
