//
//  UserIdentity.swift
//  
//
//  Created by Gerardo Grisolini on 05/03/2020.
//

import Foundation

protocol UserIdentity: OPCUAEncodable {
    var policyId: String { get }
}

struct UserIdentityToken: OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .userIdentityToken)
    let encodingMask: UInt8 = 0x01
    let userIdentity: UserIdentity

    init(userIdentity: UserIdentity) {
        self.userIdentity = userIdentity
    }

    internal var bytes: [UInt8] {
        let data = userIdentity.bytes
        return typeId.bytes + [encodingMask] + UInt32(data.count).bytes + data
    }
}

public enum UserTokenType : UInt32 {
    case anonymous = 0      //No token is required.
    case userName = 1       //A username/password token.
    case certificate = 2    //An X509v3 Certificate token.
    case issuedToken = 3    //Any WS-Security defined token.
}

struct AnonymousIdentity: UserIdentity {
   let policyId: String
    
    init(policyId: String) {
        self.policyId = policyId
    }
    
    internal var bytes: [UInt8] {
        let data = policyId.bytes
        return UInt32(data.count).bytes + data
    }
}

struct UserIdentityInfoUserName: UserIdentity {
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
        let data = policyId.bytes
        let bytes = UInt32(data.count).bytes + data
        return bytes +
            username.bytes +
            password.bytes +
            encryptionAlgorithm.bytes
    }
}

struct UserIdentityInfoX509: UserIdentity {
    let policyId: String
    let certificateData: [UInt8]
    var userTokenSignature: [UInt8] = []

    init(
        policyId: String,
        certificate: String,
        privateKey: String,
        serverCertificate: [UInt8],
        serverNonce: [UInt8],
        securityPolicy: String
    ) {
        self.policyId = policyId
        do {
            self.certificateData = [UInt8](try Data(contentsOf: URL(string: certificate)!))
            
            let dataToSign = serverCertificate + serverNonce
            let key = [UInt8](try Data(contentsOf: URL(string: privateKey)!))
            self.userTokenSignature = signature(dataToSign, key, securityPolicy)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    internal var bytes: [UInt8] {
        let data = policyId.bytes
        let bytes = UInt32(data.count).bytes + data
        return bytes + certificateData + userTokenSignature
    }

    private func signature(_ data: [UInt8], _ key: [UInt8], _ policy: String) -> [UInt8] {
        //TODO: implement signature
        fatalError("method not implemented")
    }
}
