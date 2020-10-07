//
//  GetEndpointsRequest.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class GetEndpointsRequest: MessageBase, OPCUAEncodable {

    let typeId: NodeIdNumeric = NodeIdNumeric(method: .getEndpointsRequest)
    let requestHeader: RequestHeader
    let endpointUrl: String
    var localeIds: [String] = []
    var profileUris: [String] = []
    
    internal var bytes: [UInt8] {
        let ids = UInt32(localeIds.count).bytes + localeIds.map { $0.bytes }.reduce([], +)
        let uris = UInt32(profileUris.count).bytes + profileUris.map { $0.bytes }.reduce([], +)
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
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
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.endpointUrl = endpointUrl
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.requestId = requestId
    }
}
