//
//  ReadRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

public enum TimestampsToReturn: UInt32, Sendable {
    case source = 0
    case server = 1
    case both = 2
    case neither = 3
}

struct ReadRequest: OPCUAEncodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .readRequest)
    let requestHeader: RequestHeader
    let maxAge: Double = 0
    let timestampsToReturn: TimestampsToReturn = .source
    let nodesToRead: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        nodesToRead: [ReadValue]
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
        self.nodesToRead = UInt32(nodesToRead.count).bytes + nodesToRead.map { $0.bytes }.reduce([], +)
    }

    internal var bytes: [UInt8] {
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            maxAge.bytes +
            timestampsToReturn.rawValue.bytes +
            nodesToRead
    }
}

public struct ReadValue: OPCUAEncodable, Sendable {
    public let nodeValue: NodeValue
    public let attributeId: UInt32
    public var indexRange: String? = nil
    public let dataEncoding: QualifiedName
    
    public init(
        nodeValue: NodeValue,
        attributeId: UInt32 = 0x0000000d,
        dataEncoding: QualifiedName = QualifiedName()
    ) {
        self.nodeValue = nodeValue
        self.attributeId = attributeId
        self.dataEncoding = dataEncoding
    }
    
    internal var bytes: [UInt8] {
        return nodeValue.bytes +
            attributeId.bytes +
            indexRange.bytes +
            dataEncoding.bytes
    }
}
