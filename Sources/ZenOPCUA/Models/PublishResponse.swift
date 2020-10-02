//
//  PublishResponse.swift
//  
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

import Foundation

class PublishResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    var responseHeader: ResponseHeader
    let subscriptionId: UInt32
    var availableSequenceNumbers: [UInt32] = []
    var moreNotifications: Bool
    var notificationMessage: NotificationMessage
    
    var results: [StatusCodes] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .publishResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)

        var len = UInt32(0)
        var index = 44
        subscriptionId = UInt32(bytes: bytes[index..<(index+4)])
        index += 4

        var count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                availableSequenceNumbers.append(UInt32(bytes: bytes[index..<(index+4)]))
                index += 4
            }
        }
        moreNotifications = Bool(byte: bytes[index])
        index += 1
        notificationMessage = NotificationMessage(sequenceNumber: UInt32(bytes: bytes[index..<(index+4)]))
        index += 4
        notificationMessage.publishTime = Int64(bytes: bytes[index..<(index+8)]).date
        index += 8

        super.init(bytes: bytes[0...15].map { $0 })

        count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                var dataChange = DataChange()
                dataChange.typeId = Nodes.node(index: &index, bytes: bytes)
                dataChange.encodingMask = bytes[index]
                index += 5
                
                var subCount = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                
                if let code = StatusCodes(rawValue: subCount), code == .UA_STATUSCODE_BADTIMEOUT {
                    responseHeader.serviceResult = code
                    return
                }
                
                if subCount < UInt32.max {
                    for _ in 0..<subCount {
                        let clientHandle = UInt32(bytes: bytes[index..<(index+4)])
                        index += 4
                        let item = MonitoredItemNotification(
                            clientHandle: clientHandle,
                            value: DataValue(bytes: bytes, index: &index)
                        )
                        dataChange.dataChangeNotification.monitoredItems.append(item)
                    }
                }

                subCount = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                if subCount < UInt32.max {
                    for _ in 0..<subCount {
                        len = UInt32(bytes: bytes[index..<(index+4)])
                        index += 4
                        if let text = String(bytes: bytes[index..<(index+len.int)], encoding: .utf8) {
                            let info = DiagnosticInfo(info: text)
                            dataChange.dataChangeNotification.diagnosticInfos.append(info)
                        }
                        index += len.int
                    }
                }

                notificationMessage.notificationData.append(dataChange)
            }
        }
        
        count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                if let status = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)])) {
                    results.append(status)
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
                    diagnosticInfos.append(info)
                }
                index += len.int
            }
        }
    }
}

public struct NotificationMessage {
    public var sequenceNumber: UInt32
    public var publishTime: Date = Date()
    public var notificationData: [DataChange] = []
}

public struct DataChange {
    public var typeId: Node = NodeId()
    public var encodingMask: UInt8 = 0x00
    public var dataChangeNotification: DataChangeNotification = DataChangeNotification()
}

public struct DataChangeNotification {
    public var monitoredItems: [MonitoredItemNotification] = []
    public var diagnosticInfos: [DiagnosticInfo] = []
}

public struct MonitoredItemNotification {
    public var clientHandle: UInt32
    public var value: DataValue
}

public struct StatusChangeNotification {
    
}
