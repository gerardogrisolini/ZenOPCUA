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

public struct ReadValue: OPCUAEncodable {
    let nodeId: Node
    let attributeId: UInt32
    var indexRange: String? = nil
    let dataEncoding: QualifiedName
    let monitoredId: UInt32
    
    init(
        nodeId: Node,
        monitoredId: UInt32 = 0,
        attributeId: UInt32 = 0x0000000d,
        dataEncoding: QualifiedName = QualifiedName()
    ) {
        self.nodeId = nodeId
        self.monitoredId = monitoredId
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
