//
//  UserIdentity.swift
//  
//
//  Created by Gerardo Grisolini on 05/03/2020.
//

protocol UserIdentity: OPCUAEncodable {
    var typeId: NodeIdNumeric { get }
    var encodingMask: UInt8 { get }
    var policyId: String { get }
}

public enum UserTokenType : UInt32 {
    case anonymous = 0      //No token is required.
    case userName = 1       //A username/password token.
    case certificate = 2    //An X509v3 Certificate token.
    case issuedToken = 3    //Any WS-Security defined token.
}

struct AnonymousIdentity: UserIdentity {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .userIdentityToken)
    let encodingMask: UInt8 = 0x01
    let policyId: String
    
    init(policyId: String) {
        self.policyId = policyId
    }
    
    internal var bytes: [UInt8] {
        let data = policyId.bytes
        return typeId.bytes + [encodingMask] + UInt32(data.count).bytes + data
    }
}

struct UserIdentityInfoUserName: UserIdentity {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .userIdentityToken)
    let encodingMask: UInt8 = 0x01
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
        return typeId.bytes + [encodingMask] + bytes +
            username.bytes +
            password.bytes +
            encryptionAlgorithm.bytes
    }
}

struct UserIdentityInfoX509: UserIdentity {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .userIdentityToken)
    let encodingMask: UInt8 = 0x01
    let policyId: String
    
    let certificateData: String;
    let privateKey: String;

    init(policyId: String, certificateData: String, privateKey: String) {
        self.policyId = policyId
        self.certificateData = certificateData
        self.privateKey = privateKey
    }

    internal var bytes: [UInt8] {
        let data = policyId.bytes
        let bytes = UInt32(data.count).bytes + data
        return typeId.bytes + [encodingMask] + bytes +
            certificateData.bytes +
            privateKey.bytes
    }
}

//struct UserIdentityToken: OPCUAEncodable {
//    let typeId: NodeIdNumeric = NodeIdNumeric(method: .userIdentityToken)
//    let encodingMask: UInt8 = 0x01
//    let identityToken: OPCUAEncodable
//
//    init(identityToken: OPCUAEncodable) {
//        self.identityToken = identityToken
//    }
//
//    internal var bytes: [UInt8] {
//        let data = identityToken.bytes
//        return typeId.bytes + [encodingMask] + UInt32(data.count).bytes + data
//    }
//}
