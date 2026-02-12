//
//  DataValue.swift
//
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

import Foundation


public enum DataType: UInt8, Sendable {
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
    case xmlElement = 16
    
    case arrayOfDouble = 139
    
    case nodeId = 0x11
    case qualifiedName = 0x14
    case localizedText = 0x15
}

// Concurrency: treated as immutable after decoding; not thread-safe to mutate across tasks.
public class DataValue: Promisable, OPCUAEncodable, @unchecked Sendable {
    public var encodingMask: UInt8 = 0x05
    public var variant: Variant
    public var statusCode: StatusCodes = .UA_STATUSCODE_GOOD
    public var sourceTimestamp: Date = Date()
    public var serverTimestamp: Date = Date()

    public init(bytes: [UInt8], index: inout Int) {
        encodingMask = bytes[index]
        index += 1
        variant = Variant(type: DataType.null.rawValue)

        if (encodingMask & 0x01) != 0 {
            variant = Variant(type: bytes[index])
            index += 1

            guard let dataType = DataType(rawValue: variant.type) else {
                return
            }

            switch dataType {
            case .null:
                break
            case .bool, .byte:
                variant.bytes.append(bytes[index])
                index += 1
            case .int16, .uint16:
                variant.bytes = bytes[index...(index+1)].map { $0 }
                index += 2
            case .float, .int32, .uint32:
                variant.bytes = bytes[index..<(index+4)].map { $0 }
                index += 4
            case .int64, .uint64, .double, .datetime:
                variant.bytes = bytes[index..<(index+8)].map { $0 }
                index += 8
            case .string, .byteString:
                let len = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                if len < UInt32.max {
                    variant.bytes = bytes[index..<(index+len.int)].map { $0 }
                    index += len.int
                }
            case .guid:
                variant.bytes = bytes[index..<(index+16)].map { $0 }
                index += 16
            case .nodeId:
                let len = bytes[index] == 0x0 ? 2 : 4
                variant.bytes = bytes[index..<(index+len)].map { $0 }
                index += len
            case .qualifiedName:
                variant.bytes = bytes[index...index+1].map { $0 }
                index += 2
                let len = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                if len < UInt32.max {
                    variant.bytes += bytes[index..<(index+len.int)].map { $0 }
                    index += len.int
                }
            case .localizedText, .xmlElement:
                variant.bytes = [bytes[index]]
                let len = UInt32(bytes: bytes[index+1..<(index+5)])
                index += 5
                if len < UInt32.max {
                    variant.bytes += bytes[index..<(index+len.int)].map { $0 }
                    index += len.int
                }
            case .arrayOfDouble:
                let len = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                if len < UInt32.max {
                    let arrayLenght = 8 * len.int
                    variant.bytes = [1, 139]
                    variant.bytes += bytes[index..<(index+arrayLenght)].map { $0 }
                    index += arrayLenght
                }
            }
        }

        if (encodingMask & 0x02) != 0 {
            if let status = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)])) {
                statusCode = status
            } else {
                statusCode = .UA_STATUSCODE_BADUNEXPECTEDERROR
            }
            index += 4
        }

        if (encodingMask & 0x04) != 0 {
            sourceTimestamp = Int64(bytes: bytes[index..<(index+8)]).dateUtc
            index += 8
        }

        if (encodingMask & 0x08) != 0 {
            serverTimestamp = Int64(bytes: bytes[index..<(index+8)]).dateUtc
            index += 8
        }
    }
    
    public init(variant: Variant) {
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
    
    public init(type: UInt8) {
        self.type = type
    }

    public init(value: Bool) {
        type = DataType.bool.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: UInt16) {
        type = DataType.uint16.rawValue
        bytes.append(contentsOf: value.bytes)
    }
    
    public init(value: Int16) {
        type = DataType.int16.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: UInt32) {
        type = DataType.uint32.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: Int32) {
        type = DataType.int32.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: UInt64) {
        type = DataType.uint64.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: Int64) {
        type = DataType.int64.rawValue
        bytes.append(contentsOf: value.bytes)
    }

	public init(value: Float) {
		type = DataType.float.rawValue
		bytes.append(contentsOf: value.bytes)
	}
	
	public init(value: Double) {
        type = DataType.double.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: String) {
        type = DataType.string.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: Date) {
        type = DataType.datetime.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public init(value: [Double]) {
        type = DataType.arrayOfDouble.rawValue
        bytes.append(contentsOf: value.bytes)
    }

    public var value: Any {
        switch DataType(rawValue: type) {
        case .null:
            return type
        case .bool:
            return bytes.load() as Bool
        case .uint16:
            return bytes.load() as UInt16
        case .int16:
            return bytes.load() as Int16
        case .uint32:
            return bytes.load() as UInt32
        case .int32:
            return bytes.load() as Int32
        case .float:
            return bytes.load() as Float
        case .double:
            return bytes.load() as Double
        case .string:
            return bytes.withUnsafeBytes { String(bytes: $0, encoding: .utf8)! }
        case .datetime:
            return (bytes.load() as Int64).dateUtc
        case .arrayOfDouble:
            let data = bytes.suffix(from: 2)
            let chunks = Array(data).chunked(into: 8)
            return chunks.map { $0.load() as Double }
        default:
            return bytes
        }
    }
}

public extension ContiguousBytes {
  func load<T>(_: T.Type = T.self) -> T {
    withUnsafeBytes { $0.load(as: T.self) }
  }

  func load<Element>(_: [Element].Type = [Element].self) -> [Element] {
    withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
  }
}

extension Array<UInt8> {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
