//
//  SecurityPolicies.swift
//  
//
//  Created by Gerardo Grisolini on 03/10/2020.
//

extension SecurityPolicies {
    var uri: String {
        if self == .invalid { return self.rawValue }
        return "http://opcfoundation.org/UA/SecurityPolicy#\(self.rawValue)"
    }
}
