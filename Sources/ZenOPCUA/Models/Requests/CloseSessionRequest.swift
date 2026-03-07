//
//  CloseSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

struct CloseSessionRequest: OPCUAEncodable, Sendable {

    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .closeSessionRequest)
    let requestHeader: RequestHeader
    let deleteSubscriptions: Bool

    internal var bytes: [UInt8] {
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            deleteSubscriptions.bytes
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationTokenValue: NodeValue,
        deleteSubscriptions: Bool
    ) {
        self.header = MessageHeader(
            secureChannelId: secureChannelId,
            tokenId: tokenId,
            requestId: requestId
        )
        self.deleteSubscriptions = deleteSubscriptions
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationTokenValue: authenticationTokenValue)
    }

}
