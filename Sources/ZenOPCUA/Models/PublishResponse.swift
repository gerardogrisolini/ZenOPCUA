//
//  PublishResponse.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

import Foundation

class PublishResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    let subscriptionId: UInt32
    var availableSequenceNumbers: [UInt32] = []
    let moreNotifications: Bool
    var notificationMessage: NotificationMessage
    
    var results: [StatusCodes] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .publishResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)

        var len = 0
        var index = 44
        subscriptionId = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4

        var count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                availableSequenceNumbers.append(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
            }
        }
        moreNotifications = Bool(byte: bytes[index])
        index += 1
        notificationMessage = NotificationMessage(sequenceNumber: UInt32(littleEndianBytes: bytes[index..<(index+4)]))
        index += 4
        notificationMessage.publishTime = Int64(littleEndianBytes: bytes[index..<(index+8)]).date
        index += 8

        count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                var dataChange = DataChange()
                
                switch Nodes(rawValue: bytes[index])! {
                case .numeric:
                    let nodeId = NodeIdNumeric(
                        nameSpace: bytes[index+1],
                        identifier: UInt16(littleEndianBytes: bytes[(index+2)...(index+3)])
                    )
                    dataChange.typeId = nodeId
                    index += 4
                case .string:
                    len = Int(UInt32(littleEndianBytes: bytes[(index+3)..<(index+7)]))
                    if len < UInt32.max {
                        let nodeId = NodeIdString(
                            nameSpace: UInt16(littleEndianBytes: bytes[(index+1)...(index+2)]),
                            identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8)!
                        )
                        dataChange.typeId = nodeId
                        index += len
                    }
                    index += 3 + 4
                case .guid:
                    let nodeId = NodeIdGuid(
                        nameSpace: UInt16(littleEndianBytes: bytes[(index+1)...(index+2)]),
                        identifier: NSUUID(uuidBytes: bytes[(index+3)..<(index+19)].map { $0 }) as UUID
                    )
                    dataChange.typeId = nodeId
                    index += 19
                default:
                    dataChange.typeId = NodeId(identifierNumeric: bytes[index+1])
                    index += 2
                }
                
                dataChange.encodingMask = bytes[index]
                index += 1
                
                var item = MonitoredItemNotification(clientHandle: UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 1
                
                var subCount = UInt32(littleEndianBytes: bytes[index..<(index+4)])
                index += 4
                if subCount < UInt32.max {
                    for _ in 0..<subCount {
                        item.value.append(DataValue(bytes: bytes, index: &index))
                        index += 8
                    }
                }

                subCount = UInt32(littleEndianBytes: bytes[index..<(index+4)])
                index += 4
                if subCount < UInt32.max {
                    for _ in 0..<subCount {
                        len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                        index += 4
                        if let text = String(bytes: bytes[index..<(index+len)], encoding: .utf8) {
                            let info = DiagnosticInfo(info: text)
                            dataChange.dataChangeNotification.diagnosticInfos.append(info)
                        }
                        index += len
                    }
                }

                dataChange.dataChangeNotification.monitoredItems.append(item)
                notificationMessage.notificationData.append(dataChange)
            }
        }
        
        count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        for _ in 0..<count {
            if let status = StatusCodes(rawValue: UInt32(littleEndianBytes: bytes[index..<(index+4)])) {
                results.append(status)
            }
            index += 4
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

public struct NotificationMessage {
    var sequenceNumber: UInt32
    var publishTime: Date = Date()
    var notificationData: [DataChange] = []
}

public struct DataChange: Promisable {
    var typeId: Node = NodeId()
    var encodingMask: UInt8 = 0x00
    var dataChangeNotification: DataChangeNotification = DataChangeNotification()
}

public struct DataChangeNotification {
    var monitoredItems: [MonitoredItemNotification] = []
    var diagnosticInfos: [DiagnosticInfo] = []
}

public struct MonitoredItemNotification {
    var clientHandle: UInt32
    var value: [DataValue] = []
}
