//
//  ReadRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class ReadRequest: MessageBase, OPCUAEncodable {

    let typeId: TypeId = TypeId(identifierNumeric: .browseRequest)
    let requestHeader: RequestHeader
    let maxAge: UInt64 = 0
    let timestampsToReturn: UInt32 = 0x00000000
    let nodesToRead: [ReadValueId]
    
    var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            maxAge.bytes +
            timestampsToReturn.bytes +
            nodesToRead.bytes
    }
    
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
        self.nodesToRead = nodesToRead
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}

public struct ReadValueId: OPCUAEncodable {
    public let nodeId: TypeId
    public let attributeId: UInt32
    public var indexRange: String? = nil
    public let dataEncoding: QualifiedName
    
    init(
        nodeId: TypeId,
        attributeId: UInt32,
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
