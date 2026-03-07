//
//  GetEndpointsRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

struct GetEndpointsRequest: OPCUAEncodable, Sendable {

    let header: MessageHeader

    let typeId: NodeValue = NodeValue(method: .getEndpointsRequest)
    let requestHeader: RequestHeader
    let endpointUrl: String
    var localeIds: [String] = []
    var profileUris: [String] = []
    
    internal var bytes: [UInt8] {
        let ids = UInt32(localeIds.count).bytes + localeIds.map { $0.bytes }.reduce([], +)
        let uris = UInt32(profileUris.count).bytes + profileUris.map { $0.bytes }.reduce([], +)
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            endpointUrl.bytes +
            ids +
            uris
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        endpointUrl: String
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.endpointUrl = endpointUrl
    }
}
