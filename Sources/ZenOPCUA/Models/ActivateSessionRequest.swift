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
    let userIdentityToken: UserIdentityToken = UserIdentityToken()
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
    let anonymousIdentityToken: AnonymousIdentityToken = AnonymousIdentityToken()

    var bytes: [UInt8] {
        let data = anonymousIdentityToken.bytes
        return typeId.bytes + [encodingMask] + UInt32(data.count).bytes + data
    }
}

struct AnonymousIdentityToken: OPCUAEncodable {
    let policyId: String = "Anonymous"

    var bytes: [UInt8] {
        return policyId.bytes
    }
}
