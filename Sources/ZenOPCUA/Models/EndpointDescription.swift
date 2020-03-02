//
//  EndpointDescription.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

class EndpointDescription {
    var endpointUrl: String = ""
    var server: ApplicationDescription = ApplicationDescription()
    var serverCertificate: [UInt8] = []
    var messageSecurityMode: MessageSecurityMode = .none
    var securityPolicyUri: String = "http://opcfoundation.org/UA/SecurityPolicy#None"
    var userIdentityTokens: [UserTokenPolicy] = []
    var transportProfileUri: String = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
    var securityLevel: UInt8 = 0x00
}
