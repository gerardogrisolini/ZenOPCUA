//
//  ReadResponse.swift
//  
//
//  Created by Gerardo Grisolini on 20/02/2020.
//

import Foundation

class ReadResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [DataValue] = []
    var diagnosticInfos: [DiagosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .browseResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })

        var index = 44
        var len = 0
        
        var count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        for _ in 0..<count {
            if bytes[index] == 0x02 {
                index += 1
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                print("Error: \(len) - BadNodeIdUnknow")
                index += 4
            } else {
                let data = DataValue(bytes: bytes, index: &index)
                results.append(data)
            }
        }

        count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
                if let text = String(bytes: bytes[index..<(index+len)], encoding: .utf8) {
                    let info = DiagosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
                index += len
            }
        }
    }
}

public class DataValue: Promisable {
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
}

public struct Variant {
    public var type: UInt8
    var bytes: [UInt8] = []
    
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
