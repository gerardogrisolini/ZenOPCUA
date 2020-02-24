//
//  DataValue.swift
//  
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

import Foundation

enum DataType {
    
}

public class DataValue: Promisable, OPCUAEncodable {
    public var encodingMask: UInt8 = 0x05
    public var variant: Variant
    public var sourceTimestamp: Date = Date()
    
    init(bytes: [UInt8], index: inout Int) {
        encodingMask = bytes[index]
        variant = Variant(type: bytes[index+1])
        index += 2

        switch variant.type {
        case 0x00:
            variant.bytes = bytes[index..<(index+2)].map { $0 }
            index += 2
        case 0x01:
            variant.bytes = bytes[index..<(index+4)].map { $0 }
            index += 4
        case 0x0c:
            let len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                variant.bytes = bytes[index..<(index+len)].map { $0 }
                index += len
            }
        default:
            break
        }
        
        sourceTimestamp = Int64(littleEndianBytes: bytes[index..<(index+8)]).date
        index += 8
    }
    
    init(variant: Variant) {
        encodingMask = 0x01
        self.variant = variant
    }

    var bytes: [UInt8] {
        return [encodingMask, variant.type] + variant.bytes
    }
}

public struct Variant {
    public let type: UInt8
    var bytes: [UInt8] = []
    
    init(type: UInt8) {
        self.type = type
    }

    init(value: UInt16) {
        type = 0x00
        bytes.append(contentsOf: value.bytes)
    }

    init(value: UInt32) {
        type = 0x01
        bytes.append(contentsOf: value.bytes)
    }

    init(value: String) {
        type = 0x0c
        bytes.append(contentsOf: value.bytes)
    }
    
    public var value: Any {
        return bytes.withUnsafeBytes {
            switch type {
            case 0x00:
                return $0.load(as: UInt16.self)
            case 0x01:
                return $0.load(as: UInt32.self)
            case 0x0c:
                return String(bytes: $0, encoding: .utf8)!
            default:
                return bytes
            }
        }
    }
}

//protocol VariantProtocol {
//    associatedtype T
//    var type: UInt8 { get set }
//    var value: T { get set }
//}
