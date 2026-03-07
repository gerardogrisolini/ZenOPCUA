//
//  CreateMonitoredItemsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

import Foundation

struct CreateMonitoredItemsResponse: OPCUADecodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let results: [MonitoredItemCreateResult]
    let diagnosticInfos: [DiagnosticInfo]
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .createMonitoredItemsResponse)
        if bytes.count >= 44 {
            let part = bytes[20...43].map { $0 }
            responseHeader = ResponseHeader(bytes: part)
        } else {
            responseHeader = ResponseHeader(bytes: [UInt8](repeating: 0, count: 24))
        }
        header = MessageHeader(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])
        
        var index = 44
        var parsedResults: [MonitoredItemCreateResult] = []
        var parsedDiagnosticInfos: [DiagnosticInfo] = []
        
        func readUInt32Safe() -> UInt32? {
            guard index + 4 <= bytes.count else { return nil }
            let value = UInt32(bytes: bytes[index..<(index + 4)])
            index += 4
            return value
        }

        func readByteSafe() -> UInt8? {
            guard index < bytes.count else { return nil }
            let value = bytes[index]
            index += 1
            return value
        }

        func readStringSafe() -> String? {
            guard let len = readUInt32Safe(), len != UInt32.max else { return nil }
            let count = len.int
            guard index + count <= bytes.count else { return nil }
            let value = String(bytes: bytes[index..<(index + count)], encoding: .utf8)
            index += count
            return value
        }

        let parse: () -> Void = {
            guard let initialCount = readUInt32Safe() else { return }
            var count = initialCount
            if count < UInt32.max {
                for _ in 0..<count {
                    guard let rawStatus = readUInt32Safe() else { break }
                    let statusCode = StatusCodes(rawValue: rawStatus) ?? .UA_STATUSCODE_BADDATAENCODINGINVALID
                    var result = MonitoredItemCreateResult(statusCode: statusCode)
                    guard let monitoredItemId = readUInt32Safe() else { break }
                    result.monitoredItemId = monitoredItemId
                    guard index + 8 <= bytes.count else { break }
                    result.revisedSamplingInterval = Double(bytes: bytes[index..<(index+8)].map { $0 })
                    index += 8
                    guard let revisedQueueSize = readUInt32Safe() else { break }
                    result.revisedQueueSize = revisedQueueSize
                    
                    result.filterResult.typeValue = NodeValue.parse(index: &index, bytes: bytes)
                    result.filterResult.encodingMask = readByteSafe() ?? 0
                    
                    parsedResults.append(result)
                }
            }
            
            guard let diagCount = readUInt32Safe() else { return }
            count = diagCount
            if count < UInt32.max {
                for _ in 0..<count {
                    if let text = readStringSafe() {
                        let info = DiagnosticInfo(info: text)
                        parsedDiagnosticInfos.append(info)
                    }
                }
            }
        }
        parse()
        results = parsedResults
        diagnosticInfos = parsedDiagnosticInfos
    }
}

public struct MonitoredItemCreateResult: Promisable, Sendable {
    public let statusCode: StatusCodes
    public var monitoredItemId: UInt32 = 0
    var revisedSamplingInterval: Double = 0
    var revisedQueueSize: UInt32 = 0
    var filterResult: Filter = Filter()
}
