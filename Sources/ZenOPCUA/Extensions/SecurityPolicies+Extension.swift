//
//  SecurityPolicies.swift
//  
//
//  Created by Gerardo Grisolini on 03/10/2020.
//

extension SecurityPolicies {
    var uri: String {
        "http://opcfoundation.org/UA/SecurityPolicy#\(self.rawValue)"
    }
}
