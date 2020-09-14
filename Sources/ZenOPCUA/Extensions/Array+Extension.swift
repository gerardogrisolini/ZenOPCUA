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

extension ArraySlice {
  func load<T>(as type: T.Type) -> T {
    return self.withUnsafeBytes{ $0.load(as: T.self) }
  }
}
