//
//  WriteResponse.swift
//  
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

class WriteResponse: MessageBase, OPCUADecodable, @unchecked Sendable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [StatusCodes] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .writeResponse)
        if bytes.count >= 44 {
            let part = bytes[20...43].map { $0 }
            responseHeader = ResponseHeader(bytes: part)
        } else {
            responseHeader = ResponseHeader(bytes: [UInt8](repeating: 0, count: 24))
        }
        super.init(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])

        var index = 44
        func readUInt32Safe() -> UInt32? {
            guard index + 4 <= bytes.count else { return nil }
            let value = UInt32(bytes: bytes[index..<(index + 4)])
            index += 4
            return value
        }
        func readStringSafe() -> String? {
            guard let len = readUInt32Safe(), len != UInt32.max else { return nil }
            let count = len.int
            guard index + count <= bytes.count else { return nil }
            let text = String(bytes: bytes[index..<(index + count)], encoding: .utf8)
            index += count
            return text
        }
        
        var count = readUInt32Safe() ?? 0
        for _ in 0..<count {
            guard let rawStatus = readUInt32Safe() else { break }
            if let status = StatusCodes(rawValue: rawStatus) {
                results.append(status)
            }
        }

        count = readUInt32Safe() ?? 0
        if count < UInt32.max {
            for _ in 0..<count {
                if let text = readStringSafe() {
                    let info = DiagnosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
            }
        }
    }
}
