//
//  ActivateSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

public struct DiagnosticInfo: Sendable {
    public var info: String

    public init(info: String) {
        self.info = info
    }
}

struct ActivateSessionResponse: OPCUADecodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let serverNonce: [UInt8]
    let results: [StatusCodes]
    let diagnosticInfos: [DiagnosticInfo]
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .activateSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        header = MessageHeader(bytes: bytes[0...15].map { $0 })

        var index = 44
        var parsedServerNonce: [UInt8] = []
        var parsedResults: [StatusCodes] = []
        var parsedDiagnosticInfos: [DiagnosticInfo] = []

        var len = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if len < UInt32.max {
            parsedServerNonce = bytes[index..<(index+len.int)].map { $0 }
            index += len.int
        }

        var count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                if let statusCode = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)])) {
                    parsedResults.append(statusCode)
                }
                index += 4
            }
        }
        
        count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                len = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                if let text = String(bytes: bytes[index..<(index+len.int)], encoding: .utf8) {
                    let info = DiagnosticInfo(info: text)
                    parsedDiagnosticInfos.append(info)
                }
                index += len.int
            }
        }
        serverNonce = parsedServerNonce
        results = parsedResults
        diagnosticInfos = parsedDiagnosticInfos
    }
}
