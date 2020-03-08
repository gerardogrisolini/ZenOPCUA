//
//  Double+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension Double: OPCUAEncodable, OPCUADecodable {
    
    init(bytes: [UInt8]) {
        precondition(bytes.count == 8)
        self = bytes.withUnsafeBytes{ $0.load(as: Double.self) }
    }

    internal var bytes: [UInt8] {
        var _self = self
        let bytePtr = withUnsafePointer(to: &_self) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Self>.size) {
                UnsafeBufferPointer(start: $0, count: MemoryLayout<Self>.size)
            }
        }
        return [UInt8](bytePtr)
    }
}
