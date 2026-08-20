//
//  ReadResponse.swift
//  
//
//  Created by Gerardo Grisolini on 20/02/2020.
//

struct ReadResponse: OPCUADecodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let results: [DataValue]
    let diagnosticInfos: [DiagnosticInfo]

    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .readResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        header = MessageHeader(bytes: bytes[0...15].map { $0 })

        var index = 44
        var len = UInt32(0)
        var parsedResults: [DataValue] = []
        var parsedDiagnosticInfos: [DiagnosticInfo] = []
        func readUInt32() -> UInt32? {
            guard index + 4 <= bytes.count else { return nil }
            let value = UInt32(bytes: bytes[index..<(index + 4)])
            index += 4
            return value
        }

        let parse: () -> Void = {
            guard let initialCount = readUInt32() else { return }
            var count = initialCount
            if count < UInt32.max {
                for _ in 0..<count {
                    guard index < bytes.count else { return }
                    let data = DataValue(bytes: bytes, index: &index)
                    parsedResults.append(data)
                    if data.statusCode != .UA_STATUSCODE_GOOD {
                        print("Warning: ReadResponse status code: \(data.statusCode)")
                    }
                }
            }

            guard let diagCount = readUInt32() else { return }
            count = diagCount
            if count < UInt32.max {
                for _ in 0..<count {
                    guard let length = readUInt32() else { return }
                    len = length
                    guard len < UInt32.max else { return }
                    guard index <= bytes.count else { return }
                    let maxLen = bytes.count - index
                    let len = min(maxLen, len.int)
                    if let text = String(bytes: bytes[index..<(index + len)], encoding: .utf8) {
                        let info = DiagnosticInfo(info: text)
                        parsedDiagnosticInfos.append(info)
                    }
                    index += len
                }
            }
        }
        parse()
        results = parsedResults
        diagnosticInfos = parsedDiagnosticInfos
    }
}
