//
//  CloseSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class CloseSessionRequest: MessageBase, OPCUAEncodable {

    let typeId: NodeIdNumeric = NodeIdNumeric(method: .closeSessionRequest)
    let requestHeader: RequestHeader
    let deleteSubscriptions: Bool

    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            deleteSubscriptions.bytes
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        deleteSubscriptions: Bool
    ) {
        self.deleteSubscriptions = deleteSubscriptions
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}
