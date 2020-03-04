//
//  EndpointDescription.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

/*
 endpointUrl: The URL for the Endpoint described.
 server: The description for the Server that the Endpoint belongs to.
 serverCertificate: The application instance certificate issued to the Server.
 messageSecurityMode: The type of security to apply to the messages.
 securityPolicyUri: The URI for SecurityPolicy to use when securing messages.
 userIdentityTokens: The user identity tokens that the Server will accept.
 transportProfileUri: The URI of the Transport Profile supported by the Endpoint.
 securityLevel: A numeric value that indicates how secure the EndpointDescription is compared to other EndpointDescriptions for the same Server.
 */

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
