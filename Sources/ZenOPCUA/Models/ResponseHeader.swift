//
//  ResponseHeader.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

struct ResponseHeader: OPCUADecodable {
    var timestamp: Date
    var requestHandle: UInt32
    var serviceResult: StatusCodes
    var serviceDiagnistics: UInt8
    var stringTable: UInt32
    var additionalHeader: AdditionalHeader
    
    init(bytes: [UInt8]) {
        timestamp = Int64(littleEndianBytes: bytes[0...7]).date
        requestHandle = UInt32(littleEndianBytes: bytes[8...11])
        serviceResult = StatusCodes(rawValue: UInt32(littleEndianBytes: bytes[12...15]))!
        serviceDiagnistics = bytes[16]
        stringTable = UInt32(littleEndianBytes: bytes[17...20])
        let part = bytes[21...23].map { $0 }
        additionalHeader = AdditionalHeader(bytes: part)
    }
}
