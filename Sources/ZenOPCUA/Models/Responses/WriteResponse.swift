//
//  WriteResponse.swift
//  
//
//  Created by Gerardo Grisolini on 24/02/2020.
//

struct WriteResponse: OPCUADecodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let results: [StatusCodes]
    let diagnosticInfos: [DiagnosticInfo]
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .writeResponse)
        if bytes.count >= 44 {
            let part = bytes[20...43].map { $0 }
            responseHeader = ResponseHeader(bytes: part)
        } else {
            responseHeader = ResponseHeader(bytes: [UInt8](repeating: 0, count: 24))
        }
        header = MessageHeader(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])

        var index = 44
        var parsedResults: [StatusCodes] = []
        var parsedDiagnosticInfos: [DiagnosticInfo] = []
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
                parsedResults.append(status)
            }
        }

        count = readUInt32Safe() ?? 0
        if count < UInt32.max {
            for _ in 0..<count {
                if let text = readStringSafe() {
                    let info = DiagnosticInfo(info: text)
                    parsedDiagnosticInfos.append(info)
                }
            }
        }
        results = parsedResults
        diagnosticInfos = parsedDiagnosticInfos
    }
}
