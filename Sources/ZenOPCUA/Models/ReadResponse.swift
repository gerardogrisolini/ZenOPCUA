//
//  ReadResponse.swift
//  
//
//  Created by Gerardo Grisolini on 20/02/2020.
//

class ReadResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [DataValue] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .browseResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })

        var index = 44
        var len = 0
        
        var count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        for _ in 0..<count {
            if bytes[index] == 0x02 {
                index += 1
                len = Int(UInt32(bytes: bytes[index..<(index+4)]))
                print("Error: \(len) - BadNodeIdUnknow")
                index += 4
            } else {
                let data = DataValue(bytes: bytes, index: &index)
                results.append(data)
            }
        }

        count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                len = Int(UInt32(bytes: bytes[index..<(index+4)]))
                index += 4
                if let text = String(bytes: bytes[index..<(index+len)], encoding: .utf8) {
                    let info = DiagnosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
                index += len
            }
        }
    }
}
