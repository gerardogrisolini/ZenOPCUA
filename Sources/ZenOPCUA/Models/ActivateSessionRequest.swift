//
//  ActivateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

class ActivateSessionRequest: MessageBase, OPCUAEncodable {
    
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .activateSessionRequest)
    let requestHeader: RequestHeader
    var clientSignature: SignatureData = SignatureData()
    var clientSoftwareCertificates: String? = nil
    var localeIds: String? = nil
    let userIdentityToken: UserIdentityToken

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
            userIdentityToken.bytes
    }
    
    init(
        sequenceNumber: UInt32,
        requestId: UInt32,
        session: CreateSessionResponse,
        userIdentityInfo: UserIdentityInfo
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestId, authenticationToken: session.authenticationToken)
        //self.clientSignature = userIdentityInfo.userTokenSignature
        self.userIdentityToken = UserIdentityToken(userIdentityInfo: userIdentityInfo)
        super.init()
        self.secureChannelId = session.secureChannelId
        self.tokenId = session.tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}
