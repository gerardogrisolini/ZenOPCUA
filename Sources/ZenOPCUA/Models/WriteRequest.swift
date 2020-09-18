//
//  WriteRequest.swift
//  
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

class WriteRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .writeRequest)
    let requestHeader: RequestHeader
    let nodesToWrite: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        nodesToWrite: [WriteValue]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.nodesToWrite = UInt32(nodesToWrite.count).bytes + nodesToWrite.map { $0.bytes }.reduce([], +)
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
            nodesToWrite
    }
}

public struct WriteValue: OPCUAEncodable {
    public let nodeId: Node
    public let attributeId: UInt32
    public var indexRange: String? = nil
    public let value: DataValue
    
    public init(
        nodeId: Node,
        attributeId: UInt32 = 0x0000000d,
        value: DataValue
    ) {
        self.nodeId = nodeId
        self.attributeId = attributeId
        self.value = value
    }
    
    internal var bytes: [UInt8] {
        return nodeId.bytes +
            attributeId.bytes +
            indexRange.bytes +
            value.bytes
    }
}
