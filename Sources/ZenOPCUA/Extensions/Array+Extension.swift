//
//  Array+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension Array: Promisable where Element : Promisable { }

extension Array where Element: OPCUAEncodable {
    internal var bytes: [UInt8] {
        return self.map { $0.bytes }.reduce([], +)
    }
}
