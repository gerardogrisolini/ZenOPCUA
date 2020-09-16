//
//  CreateMonitoredItemsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

import Foundation

class CreateMonitoredItemsResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [MonitoredItemCreateResult] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .createSubscriptionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        
        var index = 44

        var count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                let statusCode = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)]))!
                index += 4
                var result = MonitoredItemCreateResult(statusCode: statusCode)
                result.monitoredItemId = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                result.revisedSamplingInterval = Double(bytes: bytes[index..<(index+8)].map { $0 })
                index += 8
                result.revisedQueueSize = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                
                result.filterResult.typeId = Nodes.node(index: &index, bytes: bytes)
                result.filterResult.encodingMask = bytes[index]
                index += 1
                
                results.append(result)
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

        super.init(bytes: bytes[0...15].map { $0 })
    }
}

public struct MonitoredItemCreateResult: Promisable {
    public let statusCode: StatusCodes
    public var monitoredItemId: UInt32 = 0
    var revisedSamplingInterval: Double = 0
    var revisedQueueSize: UInt32 = 0
    var filterResult: Filter = Filter()
}
