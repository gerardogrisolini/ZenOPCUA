//
//  UserIdentity.swift
//  
//
//  Created by Gerardo Grisolini on 05/03/2020.
//

import Foundation

protocol UserIdentityInfo: OPCUAEncodable {
    var policyId: String { get }
    //var userTokenSignature: SignatureData { get set }
}

struct UserIdentityToken: OPCUAEncodable {
    let typeId: NodeIdNumeric
    let encodingMask: UInt8 = 0x01
    var userIdentityInfo: UserIdentityInfo

    init(userIdentityInfo: UserIdentityInfo) {
        self.userIdentityInfo = userIdentityInfo
        switch userIdentityInfo.self {
        case is UserIdentityInfoUserName:
            typeId = NodeIdNumeric(method: .userNameIdentityToken)
        case is UserIdentityInfoX509:
            typeId = NodeIdNumeric(method: .certificateIdentityToken)
        default:
            typeId = NodeIdNumeric(method: .anonymousIdentityToken)
        }
    }

    internal var bytes: [UInt8] {
        return typeId.bytes + [encodingMask] + userIdentityInfo.bytes
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
    var userTokenSignature: SignatureData = SignatureData()

    init(policyId: String) {
        self.policyId = policyId
    }
    
    internal var bytes: [UInt8] {
        let data = policyId.bytes
        let count = UInt32(data.count).bytes
        return count + data + userTokenSignature.bytes
    }
}

struct UserIdentityInfoUserName: UserIdentityInfo {
    let policyId: String
    let username: String
    var password: [UInt8]
    var encryptionAlgorithm: String?
    var userTokenSignature: SignatureData = SignatureData()

    init(
        policyId: String,
        username: String,
        password: String,
        serverCertificate: [UInt8],
        serverNonce: [UInt8],
        securityPolicyUri: String? = nil
    ) {
        self.policyId = policyId
        self.username = username
        self.password = password.bytes
        self.encryptionAlgorithm = nil
        
        if let securityPolicyUri = securityPolicyUri {
            let securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicyUri)
            self.encryptionAlgorithm = securityPolicy.asymmetricEncryptionAlgorithm.rawValue.split(separator: ",").first?.description
            do {
                let pwd = try securityPolicy.crypt(password: password, serverNonce: serverNonce, serverCertificate: serverCertificate)
                self.password = pwd
            } catch {
                print(error)
            }
        }
    }
    
    internal var bytes: [UInt8] {
        let len = UInt32(password.count).bytes
        let data = policyId.bytes +
            username.bytes +
            len + password +
            encryptionAlgorithm.bytes
        return UInt32(data.count).bytes + data + userTokenSignature.bytes
    }
}

struct UserIdentityInfoX509: UserIdentityInfo {
    let policyId: String
    let certificateData: [UInt8]
    var userTokenSignature: SignatureData = SignatureData()

    init(
        policyId: String,
        certificate: String,
        privateKey: String,
        serverCertificate: [UInt8],
        serverNonce: [UInt8],
        securityPolicyUri: String
    ) {
        self.policyId = policyId
        do {
            let securityPolicy = SecurityPolicy(securityPolicyUri: securityPolicyUri)

            let data = try Data(contentsOf: URL(fileURLWithPath: certificate))
            self.certificateData = securityPolicy.getCertificateEncoded(data: data)

            if securityPolicy.asymmetricSignatureAlgorithm != .none {
                let dataToSign = serverCertificate + serverNonce
                let key = try Data(contentsOf: URL(fileURLWithPath: privateKey))
                let signature = try securityPolicy.sign(dataToSign: dataToSign, privateKey: key)
                userTokenSignature = SignatureData(
                    algorithm: securityPolicy.asymmetricSignatureAlgorithm.rawValue,
                    signature: [UInt8](signature)
                )
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    internal var bytes: [UInt8] {
        let len = UInt32(certificateData.count).bytes
        let data = policyId.bytes + len + certificateData
        return UInt32(data.count).bytes + data + userTokenSignature.bytes
    }
}
