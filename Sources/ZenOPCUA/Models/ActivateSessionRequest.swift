//
//  ActivateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

class ActivateSessionRequest: MessageBase, OPCUAEncodable {

    let typeId: TypeId = TypeId(identifierNumeric: .activateSessionRequest)
    let requestHeader: RequestHeader
    let clientSignature: SignatureData = SignatureData()
    let clientSowtwareCertificates: String? = nil
    let localeIds: String? = nil
    let userIdentityToken: UserIdentityToken
    let userTokenSignature: SignatureData = SignatureData()

    var bytes: [UInt8] {
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
        secureChannelId: UInt32,
        tokenId: UInt32,
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        endpointUrl: String
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle)
        if let username = ZenOPCUA.username, let password = ZenOPCUA.password {
            let identityToken = UserNameIdentityToken(username: username, password: password)
            userIdentityToken = UserIdentityToken(identityToken: identityToken)
        } else {
            userIdentityToken = UserIdentityToken(identityToken: AnonymousIdentityToken())
        }
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }
}

struct UserIdentityToken: OPCUAEncodable {
    let typeId: TypeId = TypeId(identifierNumeric: .userIdentityToken)
    let encodingMask: UInt8 = 0x01
    let identityToken: OPCUAEncodable

    init(identityToken: OPCUAEncodable) {
        self.identityToken = identityToken
    }
    
    var bytes: [UInt8] {
        let data = identityToken.bytes
        return typeId.bytes + [encodingMask] + UInt32(data.count).bytes + data
    }
}

struct AnonymousIdentityToken: OPCUAEncodable {
    let policyId: String = "Anonymous"

    var bytes: [UInt8] {
        return policyId.bytes
    }
}

struct UserNameIdentityToken: OPCUAEncodable {
    let policyId: String = "UserName"
    let username: String
    let password: String
    let encryptionAlgorithm: String?

    init(username: String, password: String, encryptionAlgorithm: String? = nil) {
        self.username = username
        self.password = password
        self.encryptionAlgorithm = encryptionAlgorithm
    }
    
    var bytes: [UInt8] {
        return policyId.bytes +
            username.bytes +
            password.bytes +
            encryptionAlgorithm.bytes
    }
}
