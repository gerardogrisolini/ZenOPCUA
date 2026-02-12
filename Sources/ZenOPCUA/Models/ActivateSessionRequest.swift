//
//  ActivateSessionRequest.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

import Foundation

class ActivateSessionRequest: MessageBase, OPCUAEncodable, @unchecked Sendable {
    
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .activateSessionRequest)
    let requestHeader: RequestHeader
    var clientSignature: SignatureData = SignatureData()
    var clientSoftwareCertificates: [[UInt8]] = []
    var localeIds: [String] = []
    let userIdentityToken: UserIdentityToken
    let userTokenSignature: SignatureData

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
            userIdentityToken.bytes +
            userTokenSignature.bytes
    }
    
    init(
        requestId: UInt32,
        session: CreateSessionResponse,
        userIdentityInfo: UserIdentityInfo,
        securityPolicy: SecurityPolicy
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestId, authenticationToken: session.authenticationToken)
        self.userIdentityToken = UserIdentityToken(userIdentityInfo: userIdentityInfo)
        self.userTokenSignature = userIdentityInfo.userTokenSignature
        super.init()
        self.secureChannelId = session.secureChannelId
        self.tokenId = session.tokenId
        self.requestId = requestId

        if securityPolicy.asymmetricSignatureAlgorithm != .none,
           session.serverCertificate.count > 0,
           session.serverNonce.count > 0 {
            do {
                let dataToSign = Data(session.serverCertificate + session.serverNonce)
                let signature = try securityPolicy.signAsymmetric(data: dataToSign)
                self.clientSignature = SignatureData(
                    algorithm: securityPolicy.asymmetricSignatureAlgorithm.rawValue.split(separator: ",").first?.description,
                    signature: [UInt8](signature)
                )
            } catch {
                print("ActivateSessionRequest: failed to sign clientSignature: \(error)")
            }
        }
    }
}
