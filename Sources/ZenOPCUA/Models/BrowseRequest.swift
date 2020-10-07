//
//  BrowseRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

import Foundation

class BrowseRequest: MessageBase, OPCUAEncodable {

    let typeId: NodeIdNumeric = NodeIdNumeric(method: .browseRequest)
    let requestHeader: RequestHeader
    let view: ViewDescription = ViewDescription()
    let requestedMaxReferencesPerNode: UInt32 = 0
    let nodesToBrowse: [BrowseDescription]
    
    internal var bytes: [UInt8] {
        let part = UInt32(nodesToBrowse.count).bytes
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
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
        authenticationToken: Node,
        nodesToBrowse: [BrowseDescription]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.nodesToBrowse = nodesToBrowse
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.requestId = requestId
    }
}

struct ViewDescription: OPCUAEncodable {
    var viewId: NodeId = NodeId()
    var timestamp: UInt64 = 0
    var viewVersion: UInt32 = 0

    internal var bytes: [UInt8] {
        return viewId.bytes +
            timestamp.bytes +
            viewVersion.bytes
    }
}

public enum BrowseDirection: UInt32 {
    case forward = 0
    case inverse = 1
    case both = 2
}

public struct BrowseDescription: OPCUAEncodable {
    public let nodeId: Node
    public var browseDirection: BrowseDirection = .forward
    public var referenceTypeId: NodeId = NodeId()
    public var includeSubtypes: Bool = false
    var nodeClassMask: UInt32 = 0x00000000
    var resultMask: UInt32 = 0x0000003f
    
    public init(nodeId: Node = NodeId(identifier: 0x55)) {
        self.nodeId = nodeId
    }
    
    internal var bytes: [UInt8] {
        return nodeId.bytes +
            browseDirection.rawValue.bytes +
            referenceTypeId.bytes +
            includeSubtypes.bytes +
            nodeClassMask.bytes +
            resultMask.bytes
    }
}
