//
//  DataValue.swift
//  
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

import Foundation


enum DataType: UInt8 {
    case null = 0
    case bool = 1
    //case sbyte = 2
    case byte = 3
    case int16 = 4
    case uint16 = 5
    case int32 = 6
    case uint32 = 7
    case int64 = 8
    case uint64 = 9
    case float = 10
    case double = 11
    case string = 12
    case datetime = 13
    case guid = 14
    case byteString = 15
    //case xmlElement = 16
}

public class DataValue: Promisable, OPCUAEncodable {
    public var encodingMask: UInt8 = 0x05
    public var variant: Variant
    public var sourceTimestamp: Date = Date()
    public var serverTimestamp: Date = Date()

    init(bytes: [UInt8], index: inout Int) {
        encodingMask = bytes[index]
        variant = Variant(type: bytes[index+1])
        index += 2

        switch DataType(rawValue: variant.type)! {
        case .null:
            break
        case .bool, .byte:
            variant.bytes.append(bytes[index])
            index += 1
        case .int16, .uint16:
            variant.bytes = bytes[index...(index+1)].map { $0 }
            index += 2
        case .int32, .uint32:
            variant.bytes = bytes[index..<(index+4)].map { $0 }
            index += 4
        case .int64, .uint64, .double, .float, .datetime:
            variant.bytes = bytes[index..<(index+8)].map { $0 }
            index += 8
        case .string, .byteString:
            let len = Int(UInt32(bytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                variant.bytes = bytes[index..<(index+len)].map { $0 }
                index += len
            }
        case .guid:
            variant.bytes = bytes[index..<(index+16)].map { $0 }
            index += 16
        }
        
        if encodingMask == 0x0d || encodingMask == 0x05 {
            sourceTimestamp = Int64(bytes: bytes[index..<(index+8)]).date
            index += 8
        }
        
        if encodingMask == 0x0d || encodingMask == 0x09 {
            serverTimestamp = Int64(bytes: bytes[index..<(index+8)]).date
            index += 8
        }
    }
    
    init(variant: Variant) {
        encodingMask = 0x01
        self.variant = variant
    }

    internal var bytes: [UInt8] {
        return [encodingMask, variant.type] + variant.bytes
    }
}

public struct Variant {
    public let type: UInt8
    internal var bytes: [UInt8] = []
    
    init(type: UInt8) {
        self.type = type
    }

    init(value: Bool) {
        type = DataType.bool.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: UInt16) {
        type = DataType.uint16.rawValue
        bytes.append(contentsOf: value.bytes)
    }
    
    init(value: Int16) {
        type = DataType.int16.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: UInt32) {
        type = DataType.uint32.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: Int32) {
        type = DataType.int32.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: UInt64) {
        type = DataType.uint64.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: Int64) {
        type = DataType.int64.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: Double) {
        type = DataType.double.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: String) {
        type = DataType.string.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    init(value: Date) {
        type = DataType.datetime.rawValue
        bytes.append(contentsOf: value.bytes)
    }
    
    public var value: Any {
        return bytes.withUnsafeBytes {
            switch DataType(rawValue: type) {
            case .null:
                return type
            case .bool:
                return $0.load(as: Bool.self)
            case .uint16:
                return $0.load(as: UInt16.self)
            case .int16:
                return $0.load(as: Int16.self)
            case .uint32:
                return $0.load(as: UInt32.self)
            case .int32:
                return $0.load(as: Int32.self)
            case .double:
                return $0.load(as: Double.self)
            case .string:
                return String(bytes: $0, encoding: .utf8)!
            case .datetime:
                return $0.load(as: Int64.self).dateUtc
            default:
                return bytes
            }
        }
    }
}

