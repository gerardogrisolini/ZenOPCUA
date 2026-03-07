//
//  ActivateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

import Foundation

struct ActivateSessionRequest: OPCUAEncodable, Sendable {
    
    let header: MessageHeader
    let typeId: NodeValue = NodeValue(method: .activateSessionRequest)
    let requestHeader: RequestHeader
    let clientSignature: SignatureData
    let clientSoftwareCertificates: [[UInt8]]
    let localeIds: [String]
    let userIdentityToken: UserIdentityToken
    let userTokenSignature: SignatureData

    internal var bytes: [UInt8] {
        let certificates = clientSoftwareCertificates.count == 0
            ? UInt32.max.bytes
            : UInt32(clientSoftwareCertificates.count).bytes + clientSoftwareCertificates.map { $0 }.reduce([], +)
        let ids = localeIds.count == 0
            ? UInt32.max.bytes
            : UInt32(localeIds.count).bytes + localeIds.map { $0.bytes }.reduce([], +)
        return header.secureChannelId.bytes +
            header.tokenId.bytes +
            header.sequenceNumber.bytes +
            header.requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            clientSignature.bytes +
            certificates +
            ids +
            userIdentityToken.bytes +
            userTokenSignature.bytes
    }
    
    init(
        requestId: UInt32,
        session: CreateSessionResponse,
        userIdentityInfo: UserIdentityInfo,
        securityPolicy: SecurityPolicy
    ) {
        self.header = MessageHeader(
            secureChannelId: session.header.secureChannelId,
            tokenId: session.header.tokenId,
            requestId: requestId
        )
        self.requestHeader = RequestHeader(
            requestHandle: requestId,
            authenticationTokenValue: session.authenticationTokenValue
        )
        self.clientSoftwareCertificates = []
        self.localeIds = []
        self.userIdentityToken = UserIdentityToken(userIdentityInfo: userIdentityInfo)
        self.userTokenSignature = userIdentityInfo.userTokenSignature

        var signature = SignatureData()
        if securityPolicy.asymmetricSignatureAlgorithm != .none,
           session.serverCertificate.count > 0,
           session.serverNonce.count > 0 {
            do {
                let dataToSign = Data(session.serverCertificate + session.serverNonce)
                let signed = try securityPolicy.signAsymmetric(data: dataToSign)
                signature = SignatureData(
                    algorithm: securityPolicy.asymmetricSignatureAlgorithm.rawValue.split(separator: ",").first?.description,
                    signature: [UInt8](signed)
                )
            } catch {
                print("ActivateSessionRequest: failed to sign clientSignature: \(error)")
            }
        }
        self.clientSignature = signature
    }
}
