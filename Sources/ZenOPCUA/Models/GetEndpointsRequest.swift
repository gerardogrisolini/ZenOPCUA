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
    var localeIds: String? = nil
    var profileUris: String? = nil
    
    var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            endpointUrl.bytes +
            localeIds.bytes +
            profileUris.bytes
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        endpointUrl: String
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        self.endpointUrl = endpointUrl
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}
