//
//  UserIdentity.swift
//  
//
//  Created by Gerardo Grisolini on 05/03/2020.
//

import Foundation

protocol UserIdentityInfo: OPCUAEncodable {
    var policyId: String { get }
}

struct UserIdentityToken: OPCUAEncodable {
    let typeId: NodeIdNumeric
    let encodingMask: UInt8 = 0x01
    let userIdentityInfo: UserIdentityInfo

    init(userIdentityInfo: UserIdentityInfo) {
        self.userIdentityInfo = userIdentityInfo
        switch userIdentityInfo.self {
        case is UserIdentityInfoAnonymous:
            typeId = NodeIdNumeric(method: .anonymousIdentityToken)
        case is UserIdentityInfoUserName:
            typeId = NodeIdNumeric(method: .userNameIdentityToken)
        default:
            fatalError("UserIdentityInfoX509 not implemented")
        }
    }

    internal var bytes: [UInt8] {
        let data = userIdentityInfo.bytes
        let count = UInt32(data.count).bytes
        return typeId.bytes + [encodingMask] + count + data
    }
}

public enum UserTokenType : UInt32 {
    case anonymous = 0      //No token is required.
    case userName = 1       //A username/password token.
    case certificate = 2    //An X509v3 Certificate token.
    case issuedToken = 3    //Any WS-Security defined token.
}

struct UserIdentityInfoAnonymous: UserIdentityInfo {
    let policyId: String
    
    init(policyId: String) {
        self.policyId = policyId
    }
    
    internal var bytes: [UInt8] {
        return policyId.bytes
    }
}

struct UserIdentityInfoUserName: UserIdentityInfo {
    let policyId: String
    let username: String
    var password: String
    var encryptionAlgorithm: String?

    init(policyId: String, username: String, password: String, securityPolicyUri: String? = nil) {
        self.policyId = policyId
        self.username = username
        self.password = password
        self.encryptionAlgorithm = nil
        
        if let securityPolicyUri = securityPolicyUri {
            let securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicyUri)
            self.encryptionAlgorithm = securityPolicy.asymmetricEncryptionAlgorithm.rawValue.split(separator: ",").first?.description
            self.password = securityPolicy.crypt(value: password)
        }
    }
    
    internal var bytes: [UInt8] {
        return policyId.bytes +
            username.bytes +
            password.bytes +
            encryptionAlgorithm.bytes
    }
}

struct UserIdentityInfoX509: UserIdentityInfo {
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
        return policyId.bytes + certificateData + userTokenSignature
    }

    private func signature(_ data: [UInt8], _ key: [UInt8], _ policy: String) -> [UInt8] {
        
        // TODO: implement signature
        // 1. get algorithm from policy
        // 2. sign data with key
        
        fatalError("method not implemented")
    }
}
