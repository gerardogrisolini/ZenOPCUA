//
//  CreateMonitoredItemsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

import Foundation

class CreateMonitoredItemsResponse: MessageBase, OPCUADecodable, @unchecked Sendable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [MonitoredItemCreateResult] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .createMonitoredItemsResponse)
        if bytes.count >= 44 {
            let part = bytes[20...43].map { $0 }
            responseHeader = ResponseHeader(bytes: part)
        } else {
            responseHeader = ResponseHeader(bytes: [UInt8](repeating: 0, count: 24))
        }
        
        var index = 44
        
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

        guard let initialCount = readUInt32Safe() else {
            super.init(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])
            return
        }
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
                
                result.filterResult.typeId = Nodes.node(index: &index, bytes: bytes)
                result.filterResult.encodingMask = readByteSafe() ?? 0
                
                results.append(result)
            }
        }
        
        guard let diagCount = readUInt32Safe() else {
            super.init(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])
            return
        }
        count = diagCount
        if count < UInt32.max {
            for _ in 0..<count {
                if let text = readStringSafe() {
                    let info = DiagnosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
            }
        }

        super.init(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])
    }
}

public struct MonitoredItemCreateResult: Promisable, Sendable {
    public let statusCode: StatusCodes
    public var monitoredItemId: UInt32 = 0
    var revisedSamplingInterval: Double = 0
    var revisedQueueSize: UInt32 = 0
    var filterResult: Filter = Filter()
}
