//
//  UserTokenPolicy.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

struct UserTokenPolicy {
    var policyId: String = "Anonymous"
    var userTokenType: UserTokenType = .anonymous
    var issuedTokenType: String? = nil
    var issuerEndpointUrl: String? = nil
    var securityPolicyUri: String? = nil
}
