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
        
        var len = 0
        var index = 44

        var count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                let statusCode = StatusCodes(rawValue: UInt32(littleEndianBytes: bytes[index..<(index+4)]))!
                index += 4
                var result = MonitoredItemCreateResult(statusCode: statusCode)
                result.monitoredItemId = UInt32(littleEndianBytes: bytes[index..<(index+4)])
                index += 4
                result.revisedSamplingInterval = Double(bytes: bytes[index..<(index+8)].map { $0 })
                index += 8
                result.revisedQueueSize = UInt32(littleEndianBytes: bytes[index..<(index+4)])
                index += 4
                
                switch Nodes(rawValue: bytes[index])! {
                case .numeric:
                    let nodeId = NodeIdNumeric(
                        nameSpace: bytes[index+1],
                        identifier: UInt16(littleEndianBytes: bytes[(index+2)...(index+3)])
                    )
                    result.filterResult.typeId = nodeId
                    index += 4
                case .string:
                    len = Int(UInt32(littleEndianBytes: bytes[(index+3)..<(index+7)]))
                    if len < UInt32.max {
                        let nodeId = NodeIdString(
                            nameSpace: UInt16(littleEndianBytes: bytes[(index+1)...(index+2)]),
                            identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8)!
                        )
                        result.filterResult.typeId = nodeId
                        index += len
                    }
                    index += 3 + 4
                case .guid:
                    let nodeId = NodeIdGuid(
                        nameSpace: UInt16(littleEndianBytes: bytes[(index+1)...(index+2)]),
                        identifier: bytes[(index+3)..<(index+19)].map { $0 }
                    )
                    result.filterResult.typeId = nodeId
                    index += 19
                default:
                    result.filterResult.typeId = NodeId(identifierNumeric: bytes[index+1])
                    index += 2
                }
                
                result.filterResult.encodingMask = bytes[index]
                index += 1
                
                results.append(result)
            }
        }
        
        count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
                if let text = String(bytes: bytes[index..<(index+len)], encoding: .utf8) {
                    let info = DiagnosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
                index += len
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
