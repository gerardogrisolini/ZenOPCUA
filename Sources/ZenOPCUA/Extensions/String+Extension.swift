//
//  String+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension String {
    var securityPolicy: SecurityPolicies {
        if let index = self.lastIndex(of: "#") {
            let algorithm = self[self.index(after: index)...]
            return SecurityPolicies(rawValue: algorithm.description)!
        }
        return .invalid
    }
}

extension String: OPCUAEncodable {
    internal var bytes: [UInt8] {
        let len = self.isEmpty ? UInt32.max : UInt32(self.utf8.count)
        return len.bytes + self.utf8.map { $0 }
    }
}

extension Optional where Wrapped == String {
    internal var bytes: [UInt8] {
        self == nil ? UInt32.max.bytes : self!.bytes
    }
}
