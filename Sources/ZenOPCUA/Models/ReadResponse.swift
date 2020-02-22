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
        typeId = NodeIdNumeric(identifier: .browseResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })

        var index = 44
        var len = 0
        
        var count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        for _ in 0..<count {
            
            var data = DataValue(variant: Variant(type: bytes[index+1]))
            data.encodingMask = bytes[index]
            index += 2

            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                data.variant.value = bytes[index..<(index+len)].map { $0 }
                index += len
            }

            data.sourceTimestamp = Int64(littleEndianBytes: bytes[index..<(index+8)]).date
            index += 8

            results.append(data)
        }

        count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
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

struct DataValue {
    var encodingMask: UInt8 = 0x05
    var variant: Variant
    var sourceTimestamp: Date = Date()
}

//protocol VariantProtocol {
//    associatedtype T
//    var type: UInt8 { get set }
//    var value: T { get set }
//}

struct Variant {
    var type: UInt8
    var value: [UInt8] = []
}
