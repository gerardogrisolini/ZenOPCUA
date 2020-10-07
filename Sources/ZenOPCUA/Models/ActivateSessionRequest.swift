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
    var clientSoftwareCertificates: [[UInt8]] = []
    var localeIds: [String] = []
    let userIdentityToken: UserIdentityToken

    internal var bytes: [UInt8] {
        let certificates = clientSoftwareCertificates.count == 0
            ? UInt32.max.bytes
            : UInt32(clientSoftwareCertificates.count).bytes + clientSoftwareCertificates.map { $0 }.reduce([], +)
        let ids = localeIds.count == 0
            ? UInt32.max.bytes
            : UInt32(localeIds.count).bytes + localeIds.map { $0.bytes }.reduce([], +)
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            clientSignature.bytes +
            certificates +
            ids +
            userIdentityToken.bytes
    }
    
    init(
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
        self.requestId = requestId
    }
}
