//
//  CreateMonitoredItemsRequest.swift
//  
//
//  Created by Gerardo Grisolini on 25/02/2020.
//

class CreateMonitoredItemsRequest: MessageBase, OPCUAEncodable {
    let typeId: NodeIdNumeric = NodeIdNumeric(method: .createMonitoredItemsRequest)
    let requestHeader: RequestHeader
    let subscriptionId: UInt32
    let timestampsToReturn: UInt32 = 0x00000002
    let itemsToCreate: [UInt8]
    
    init(
        secureChannelId: UInt32,
        tokenId: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        subscriptionId: UInt32,
        itemsToCreate: [MonitoredItemCreateRequest]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.subscriptionId = subscriptionId
        self.itemsToCreate = UInt32(itemsToCreate.count).bytes + itemsToCreate.map { $0.bytes }.reduce([], +)
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.requestId = requestId
    }

    internal var bytes: [UInt8] {
        return secureChannelId.bytes +
            tokenId.bytes +
            sequenceNumber.bytes +
            requestId.bytes +
            typeId.bytes +
            requestHeader.bytes +
            subscriptionId.bytes +
            timestampsToReturn.bytes +
            itemsToCreate
    }
}

/*
 *  disabled: The item being monitored is not sampled or evaluated, and Notifications are not generated or queued. Notification reporting is disabled.
 *  sampling: The item being monitored is sampled and evaluated, and Notifications are generated and queued. Notification reporting is disabled.
 *  reporting: The item being monitored is sampled and evaluated, and Notifications are generated and queued. Notification reporting is enabled.
 */

public enum MonitorigMode: UInt32 {
    case disabled = 0
    case sampling = 1
    case reporting = 2
}

public struct MonitoredItemCreateRequest: OPCUAEncodable {
    public let itemToMonitor: ReadValue
    public let monitorigMode: MonitorigMode
    public let requestedParameters: MonitoringParameters

    public init(itemToMonitor: ReadValue, requestedParameters: MonitoringParameters, monitorigMode: MonitorigMode = .reporting) {
        self.itemToMonitor = itemToMonitor
        self.monitorigMode = monitorigMode
        self.requestedParameters = requestedParameters
    }
    
    internal var bytes: [UInt8] {
        return itemToMonitor.bytes +
            monitorigMode.rawValue.bytes +
            requestedParameters.bytes
    }
}

/*
 * clientHandle: Client-supplied id of the MonitoredItem.
 * samplingInterval: The interval in milliseconds that defines the fastest rate at which the MonitoredItem(s) should be accessed and evaluated.
 * filter: A filter used by the Server to determine if the MonitoredItem should generate a Notification.
 * queueSize: The requested size of the MonitoredItem queue.
 * discardOldest: A boolean parameter that specifies the discard policy when the queue is full and a new Notification is to be enqueued.
 */

public struct MonitoringParameters: OPCUAEncodable {
    public let clientHandle: UInt32
    public let samplingInterval: Double
    public var filter: Filter = Filter()
    public var queueSize: UInt32 = 1
    public var discardOldest: Bool = true

    public init(clientHandle: UInt32 = 1, samplingInterval: Double = 250) {
        self.clientHandle = clientHandle
        self.samplingInterval = samplingInterval
    }
    
    internal var bytes: [UInt8] {
        return clientHandle.bytes +
            samplingInterval.bytes +
            filter.bytes +
            queueSize.bytes +
            discardOldest.bytes
    }
}

public struct Filter: OPCUAEncodable {
    public var typeId: Node = NodeId()
    public var encodingMask: UInt8 = 0x00

    internal var bytes: [UInt8] {
        return typeId.bytes + encodingMask.bytes
    }
}
