//
//  PublishResponse.swift
//
//
//  Created by Gerardo Grisolini on 26/02/2020.
//

import Foundation

struct PublishResponse: OPCUADecodable, Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    var responseHeader: ResponseHeader
    let subscriptionId: UInt32
    let availableSequenceNumbers: [UInt32]
    let moreNotifications: Bool
    let notificationMessage: NotificationMessage
    
    let results: [StatusCodes]
    let diagnosticInfos: [DiagnosticInfo]
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .publishResponse)
        header = MessageHeader(bytes: bytes[0...15].map { $0 })

        let parsed = { () -> (
            ResponseHeader,
            UInt32,
            [UInt32],
            Bool,
            NotificationMessage,
            [StatusCodes],
            [DiagnosticInfo]
        ) in
            var parsedResponseHeader = ResponseHeader(bytes: bytes[20...43].map { $0 })
            var len = UInt32(0)
            var index = 44
            let parsedSubscriptionId = UInt32(bytes: bytes[index..<(index+4)])
            index += 4

            var parsedAvailableSequenceNumbers: [UInt32] = []
            var count = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if count < UInt32.max {
                for _ in 0..<count {
                    parsedAvailableSequenceNumbers.append(UInt32(bytes: bytes[index..<(index+4)]))
                    index += 4
                }
            }
            let parsedMoreNotifications = Bool(byte: bytes[index])
            index += 1

            var parsedNotificationMessage = NotificationMessage(sequenceNumber: UInt32(bytes: bytes[index..<(index+4)]))
            index += 4
            parsedNotificationMessage.publishTime = Int64(bytes: bytes[index..<(index+8)]).date
            index += 8

            count = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if count < UInt32.max {
                for _ in 0..<count {
                    var dataChange = DataChange()
                    dataChange.typeValue = NodeValue.parse(index: &index, bytes: bytes)
                    dataChange.encodingMask = bytes[index]
                    index += 5
                    
                    var subCount = UInt32(bytes: bytes[index..<(index+4)])
                    index += 4
                    
                    if let code = StatusCodes(rawValue: subCount), code == .UA_STATUSCODE_BADTIMEOUT {
                        parsedResponseHeader.serviceResult = code
                        return (
                            parsedResponseHeader,
                            parsedSubscriptionId,
                            parsedAvailableSequenceNumbers,
                            parsedMoreNotifications,
                            parsedNotificationMessage,
                            [],
                            []
                        )
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

                    parsedNotificationMessage.notificationData.append(dataChange)
                }
            }
            
            var parsedResults: [StatusCodes] = []
            count = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if count < UInt32.max {
                for _ in 0..<count {
                    if let status = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)])) {
                        parsedResults.append(status)
                    }
                    index += 4
                }
            }
            
            var parsedDiagnosticInfos: [DiagnosticInfo] = []
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

            return (
                parsedResponseHeader,
                parsedSubscriptionId,
                parsedAvailableSequenceNumbers,
                parsedMoreNotifications,
                parsedNotificationMessage,
                parsedResults,
                parsedDiagnosticInfos
            )
        }()

        responseHeader = parsed.0
        subscriptionId = parsed.1
        availableSequenceNumbers = parsed.2
        moreNotifications = parsed.3
        notificationMessage = parsed.4
        results = parsed.5
        diagnosticInfos = parsed.6
    }
}

public struct NotificationMessage: Sendable {
    public var sequenceNumber: UInt32
    public var publishTime: Date = Date()
    public var notificationData: [DataChange] = []
}

public struct DataChange: Sendable {
    public var typeValue: NodeValue = .base(identifier: 0)
    public var encodingMask: UInt8 = 0x00
    public var dataChangeNotification: DataChangeNotification = DataChangeNotification()
}

public struct DataChangeNotification: Sendable {
    public var monitoredItems: [MonitoredItemNotification] = []
    public var diagnosticInfos: [DiagnosticInfo] = []
}

public struct MonitoredItemNotification: Sendable {
    public var clientHandle: UInt32
    public var value: DataValue
}

public struct StatusChangeNotification: Sendable {

}
