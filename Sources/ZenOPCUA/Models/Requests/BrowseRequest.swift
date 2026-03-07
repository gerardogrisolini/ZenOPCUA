//
//  BrowseRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

import Foundation

struct BrowseRequest: OPCUAEncodable, Sendable {

    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .browseRequest)
    let requestHeader: RequestHeader
    let view: ViewDescription = ViewDescription()
    let requestedMaxReferencesPerNode: UInt32 = 0
    let nodesToBrowse: [BrowseDescription]
    
    internal var bytes: [UInt8] {
        let part = UInt32(nodesToBrowse.count).bytes
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            view.bytes +
            requestedMaxReferencesPerNode.bytes +
            part + nodesToBrowse.bytes
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        nodesToBrowse: [BrowseDescription]
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
        self.nodesToBrowse = nodesToBrowse
    }

}

struct ViewDescription: OPCUAEncodable, Sendable {
    var viewValue: NodeValue = .base(identifier: 0)
    var timestamp: UInt64 = 0
    var viewVersion: UInt32 = 0

    internal var bytes: [UInt8] {
        return viewValue.bytes +
            timestamp.bytes +
            viewVersion.bytes
    }
}

public enum BrowseDirection: UInt32, Sendable {
    case forward = 0
    case inverse = 1
    case both = 2
}

public struct BrowseDescription: OPCUAEncodable, Sendable {
    public let nodeValue: NodeValue
    public var browseDirection: BrowseDirection = .forward
    public var referenceTypeValue: NodeValue = .base(identifier: 0)
    public var includeSubtypes: Bool = false
    var nodeClassMask: UInt32 = 0x00000000
    var resultMask: UInt32 = 0x0000003f
    
    public init(nodeValue: NodeValue) {
        self.nodeValue = nodeValue
    }
    
    internal var bytes: [UInt8] {
        return nodeValue.bytes +
            browseDirection.rawValue.bytes +
            referenceTypeValue.bytes +
            includeSubtypes.bytes +
            nodeClassMask.bytes +
            resultMask.bytes
    }
}
