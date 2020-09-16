//
//  DeleteSubscriptionsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

class DeleteSubscriptionsResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [StatusCodes] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .activateSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })

        var index = 44

        var count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                if let statusCode = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)])) {
                    results.append(statusCode)
                }
                index += 4
            }
        }
        
        count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                let len = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                if let text = String(bytes: bytes[index..<(index+len.int)], encoding: .utf8) {
                    let info = DiagnosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
                index += len.int
            }
        }
    }
}
