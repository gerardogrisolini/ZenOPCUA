//
//  UserTokenPolicy.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

/*
 policyId: An identifier for the UserTokenPolicy assigned by the Server.
 tokenType: The type of user identity token required.
 issuedTokenType: A URI for the type of token.
 issuerEndpointUrl: An optional URL for the token issuing service.
 securityPolicyUri: The security policy to use when encrypting or signing the UserIdentityToken when it is passed to the Server in the ActivateSession request.
 */

struct UserTokenPolicy {
    var policyId: String = "Anonymous"
    var tokenType: UserTokenType = .anonymous
    var issuedTokenType: String? = nil
    var issuerEndpointUrl: String? = nil
    var securityPolicyUri: String? = nil
}
