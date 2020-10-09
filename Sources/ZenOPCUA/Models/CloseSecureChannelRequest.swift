//
//  CloseSecureChannelRequest.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class CloseSecureChannelRequest: MessageBase, OPCUAEncodable {

    let typeId: NodeIdNumeric = NodeIdNumeric(method: .closeSecureChannelRequest)
    let requestHeader: RequestHeader

    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes
    }
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        super.init(bytes: [])
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.requestId = requestId
    }
}
