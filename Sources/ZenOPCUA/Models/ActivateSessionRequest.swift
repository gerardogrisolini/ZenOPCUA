//
//  ActivateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

class ActivateSessionRequest: MessageBase, OPCUAEncodable {

    let typeId: NodeIdNumeric = NodeIdNumeric(method: .activateSessionRequest)
    let requestHeader: RequestHeader
    let clientSignature: SignatureData = SignatureData()
    let clientSoftwareCertificates: String? = nil
    let localeIds: String? = nil
    let userIdentityToken: UserIdentityToken
    let userTokenSignature: SignatureData = SignatureData()

    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            clientSignature.bytes +
            clientSoftwareCertificates.bytes +
            localeIds.bytes +
            userIdentityToken.bytes +
            userTokenSignature.bytes
    }
    
    init(
        sequenceNumber: UInt32,
        requestId: UInt32,
        session: CreateSessionResponse,
        userIdentityToken: UserIdentityToken
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestId, authenticationToken: session.authenticationToken)
        self.userIdentityToken = userIdentityToken
        super.init()
        self.secureChannelId = session.secureChannelId
        self.tokenId = session.tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}
