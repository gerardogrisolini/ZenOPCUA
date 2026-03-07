//
//  WriteRequest.swift
//  
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

struct WriteRequest: OPCUAEncodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .writeRequest)
    let requestHeader: RequestHeader
    let nodesToWrite: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        nodesToWrite: [WriteValue]
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
        self.nodesToWrite = UInt32(nodesToWrite.count).bytes + nodesToWrite.map { $0.bytes }.reduce([], +)
    }

    internal var bytes: [UInt8] {
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            nodesToWrite
    }
}

public struct WriteValue: OPCUAEncodable, Sendable {
    public let nodeValue: NodeValue
    public let attributeId: UInt32
    public var indexRange: String? = nil
    public let value: DataValue
    
    public init(
        nodeValue: NodeValue,
        attributeId: UInt32 = 0x0000000d,
        value: DataValue
    ) {
        self.nodeValue = nodeValue
        self.attributeId = attributeId
        self.value = value
    }
    
    internal var bytes: [UInt8] {
        return nodeValue.bytes +
            attributeId.bytes +
            indexRange.bytes +
            value.bytes
    }
}
