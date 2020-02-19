//
//  ActivateSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

struct DiagosticInfo {
    var info: String
}

class ActivateSessionResponse: MessageBase, OPCUADecodable {
    let typeId: TypeId
    let responseHeader: ResponseHeader
    var serverNonce: String? = nil
    var results: [StatusCodes] = []
    var diagnosticInfos: [DiagosticInfo] = []
    
    required init(bytes: [UInt8]) {
        typeId = TypeId(identifierNumeric: .activateSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init()
        secureChannelId = UInt32(littleEndianBytes: bytes[0...3])
        tokenId = UInt32(littleEndianBytes: bytes[4...7])

        var index = 44

        var len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
        index += 4
        if len < UInt32.max {
            serverNonce = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
            index += len
        }

        var count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        for _ in 0..<count {
            if let statusCode = StatusCodes(rawValue: UInt32(littleEndianBytes: bytes[index..<(index+4)])) {
                results.append(statusCode)
            }
            index += 4
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
