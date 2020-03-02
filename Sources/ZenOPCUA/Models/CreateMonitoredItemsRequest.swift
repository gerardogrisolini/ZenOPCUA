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
        sequenceNumber: UInt32,
        requestId: UInt32,
        requestHandle: UInt32,
        authenticationToken: Node,
        subscriptionId: UInt32,
        itemsToCreate: [ReadValue]
    ) {
        self.requestHeader = RequestHeader(requestHandle: requestHandle, authenticationToken: authenticationToken)
        self.subscriptionId = subscriptionId
        
        let requests = itemsToCreate.map { readValue -> MonitoredItemCreateRequest in
            MonitoredItemCreateRequest(itemToMonitor: readValue, clientHandle: readValue.monitoredId)
        }
        self.itemsToCreate = UInt32(requests.count).bytes + requests.map { $0.bytes }.reduce([], +)
        super.init()
        self.secureChannelId = secureChannelId
        self.tokenId = tokenId
        self.sequenceNumber = sequenceNumber
        self.requestId = requestId
    }

    var bytes: [UInt8] {
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

struct MonitoredItemCreateRequest: OPCUAEncodable {
    let itemToMonitor: ReadValue
    let monitorigMode: UInt32 = 0x00000002
    let requestedParameters: MonitoringParameters

    init(itemToMonitor: ReadValue, clientHandle: UInt32) {
        self.itemToMonitor = itemToMonitor
        self.requestedParameters = MonitoringParameters(clientHandle: clientHandle)
    }
    
    var bytes: [UInt8] {
        return itemToMonitor.bytes +
            monitorigMode.bytes +
            requestedParameters.bytes
    }
}

struct MonitoringParameters: OPCUAEncodable {
    let clientHandle: UInt32
    let samplingInterval: Double = 250
    let filter: Filter = Filter()
    let queueSize: UInt32 = 1
    let discardOldest: Bool = true

    init(clientHandle: UInt32) {
        self.clientHandle = clientHandle
    }

    var bytes: [UInt8] {
        return clientHandle.bytes +
            samplingInterval.bytes +
            filter.bytes +
            queueSize.bytes +
            discardOldest.bytes
    }
}

struct Filter: OPCUAEncodable {
    var typeId: Node = NodeId()
    var encodingMask: UInt8 = 0x00

    var bytes: [UInt8] {
        return typeId.bytes + encodingMask.bytes
    }
}
