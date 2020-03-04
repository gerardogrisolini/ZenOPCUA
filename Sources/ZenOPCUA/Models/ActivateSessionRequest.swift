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
    let clientSowtwareCertificates: String? = nil
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
            clientSowtwareCertificates.bytes +
            localeIds.bytes +
            userIdentityToken.bytes +
            userTokenSignature.bytes
    }
    
    init(
        sequenceNumber: UInt32,
        requestId: UInt32,
        username: String?,
        password: String?,
        session: CreateSessionResponse
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestId, authenticationToken: session.authenticationToken)
        
        if let username = username, let password = password {
            let policyId = session.serverEndpoints.first!.userIdentityTokens.first(where: { $0.tokenType == .userName })!.policyId
            let identityToken = UserNameIdentityToken(policyId: policyId, username: username, password: password)
            userIdentityToken = UserIdentityToken(identityToken: identityToken)
        } else {
            let policyId = session.serverEndpoints.first!.userIdentityTokens.first(where: { $0.tokenType == .anonymous })!.policyId
            userIdentityToken = UserIdentityToken(identityToken: AnonymousIdentityToken(policyId: policyId))
        }
        super.init()
        self.secureChannelId = session.secureChannelId
        self.tokenId = session.tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}

struct UserIdentityToken: OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .userIdentityToken)
    let encodingMask: UInt8 = 0x01
    let identityToken: OPCUAEncodable

    init(identityToken: OPCUAEncodable) {
        self.identityToken = identityToken
    }
    
    internal var bytes: [UInt8] {
        let data = identityToken.bytes
        return typeId.bytes + [encodingMask] + UInt32(data.count).bytes + data
    }
}

struct AnonymousIdentityToken: OPCUAEncodable {
    let policyId: String
    
    init(policyId: String) {
        self.policyId = policyId
    }
    
    internal var bytes: [UInt8] {
        return policyId.bytes
    }
}

struct UserNameIdentityToken: OPCUAEncodable {
    let policyId: String
    let username: String
    let password: String
    let encryptionAlgorithm: String?

    init(policyId: String, username: String, password: String, encryptionAlgorithm: String? = nil) {
        self.policyId = policyId
        self.username = username
        self.password = password
        self.encryptionAlgorithm = encryptionAlgorithm
    }
    
    internal var bytes: [UInt8] {
        return policyId.bytes +
            username.bytes +
            password.bytes +
            encryptionAlgorithm.bytes
    }
}
