//
//  UserIdentity.swift
//  
//
//  Created by Gerardo Grisolini on 05/03/2020.
//

import Foundation

protocol UserIdentityInfo: OPCUAEncodable, Sendable {
    var policyId: String { get }
    var userTokenSignature: SignatureData { get }
}

struct UserIdentityToken: OPCUAEncodable, Sendable {
    let typeId: NodeValue
    let encodingMask: UInt8 = 0x01
    var userIdentityInfo: UserIdentityInfo

    init(userIdentityInfo: UserIdentityInfo) {
        self.userIdentityInfo = userIdentityInfo
        switch userIdentityInfo.self {
        case is UserIdentityInfoUserName:
            typeId = NodeValue(method: .userNameIdentityToken)
        case is UserIdentityInfoX509:
            typeId = NodeValue(method: .certificateIdentityToken)
        default:
            typeId = NodeValue(method: .anonymousIdentityToken)
        }
    }

    internal var bytes: [UInt8] {
        let body = userIdentityInfo.bytes
        let length = UInt32(body.count).bytes
        return typeId.bytes + [encodingMask] + length + body
    }
}

public enum UserTokenType : UInt32, Sendable {
    case anonymous = 0      //No token is required.
    case userName = 1       //A username/password token.
    case certificate = 2    //An X509v3 Certificate token.
    case issuedToken = 3    //Any WS-Security defined token.
}

struct UserIdentityInfoAnonymous: UserIdentityInfo {
    let policyId: String
    var userTokenSignature: SignatureData = SignatureData()

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
    var password: [UInt8] = []
    var encryptionAlgorithm: String?
    var userTokenSignature: SignatureData = SignatureData()

    init(
        policyId: String,
        username: String,
        password: String,
        serverNonce: [UInt8],
        serverCertificate: [UInt8],
        securityPolicyUri: String? = nil
    ) {
        self.policyId = policyId
        self.username = username
        self.encryptionAlgorithm = nil

        guard let securityPolicyUri = securityPolicyUri,
              !securityPolicyUri.isEmpty,
              securityPolicyUri != SecurityPolicies.none.uri else {
            self.password = password.utf8.map { $0 }
            return
        }

        let securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicyUri)
        if !serverCertificate.isEmpty {
            securityPolicy.loadRemoteCertificate(data: serverCertificate)
        }
        self.encryptionAlgorithm = securityPolicy.asymmetricEncryptionAlgorithm.rawValue.split(separator: ",").first?.description
        do {
            let passwordBytes = password.utf8.map { $0 }
            let payloadLength = UInt32(passwordBytes.count + serverNonce.count).bytes
            let dataToEncrypt = payloadLength + passwordBytes + serverNonce
            self.password = try securityPolicy.cryptAsymmetric(data: dataToEncrypt)
        } catch {
            print("UserIdentityInfoUserName: failed to encrypt password: \(error)")
        }
    }
    
    internal var bytes: [UInt8] {
        let len = UInt32(password.count).bytes
        return policyId.bytes +
            username.bytes +
            len + password +
            encryptionAlgorithm.bytes
    }
}

struct UserIdentityInfoX509: UserIdentityInfo {
    let policyId: String
    var certificateData: [UInt8] = []
    var userTokenSignature: SignatureData = SignatureData()

    init(
        policyId: String,
        certificate: Data,
        serverCertificate: [UInt8],
        serverNonce: [UInt8],
        securityPolicy: SecurityPolicy
    ) {
        self.policyId = policyId
        do {
            self.certificateData = [UInt8](certificate)

            if securityPolicy.asymmetricSignatureAlgorithm != .none {
                let dataToSign = Data(serverCertificate + serverNonce)
                let signature = try securityPolicy.signAsymmetric(data: dataToSign)
                userTokenSignature = SignatureData(
                    algorithm: securityPolicy.asymmetricSignatureAlgorithm.rawValue.split(separator: ",").first?.description,
                    signature: [UInt8](signature)
                )
            }
        } catch {
            self.certificateData = [UInt8](certificate)
            self.userTokenSignature = SignatureData()
            print("UserIdentityInfoX509: failed to build user token signature: \(error)")
        }
    }

    internal var bytes: [UInt8] {
        let len = UInt32(certificateData.count).bytes
        return policyId.bytes + len + certificateData
    }
}
