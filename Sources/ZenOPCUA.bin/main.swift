import NIO
import ZenOPCUA


let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

let opcua = ZenOPCUA(
    eventLoopGroup: eventLoopGroup,
    endpointUrl: "opc.tcp://10.10.57.63:4842",
    messageSecurityMode: .none,
    securityPolicy: .none
)

opcua.onHandlerActivated = {
    print("OPCUA Client Activated")
}
opcua.onHandlerRemoved = {
    print("OPCUA Client Removed")
}
opcua.onErrorCaught = { error in
    print(error)
}

opcua.onDataChanged = { data in
    data.forEach { dataChange in
        dataChange.dataChangeNotification.monitoredItems.forEach { item in
            print("read: \(item.value.variant.value)")
        }
    }
}

try opcua.connect(reconnect: false).wait()
            
//            let nodes: [BrowseDescription] = [
//                BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253)),
//                BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2256))
//            ]
//            let nodes = try opcua.browse().wait()
//            for item in nodes {
//                item.references.forEach { ref in
//                    print("\(ref.displayName.text): \(ref.nodeId)")
//                }
//            }
            
//            let deleted = try opcua.deleteSubscriptions(subscriptionIds: [subId]).wait()
//            deleted.forEach { result in
//                print("deleteSubscription: \(result)")
//            }

let reads = [ReadValue(nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20045))]
let readed = try opcua.read(nodes: reads).wait()
print(readed.first?.variant.value ?? "nil")

//
//            let subscription = Subscription(
//                requestedPubliscingInterval: 1000,
//                publishingEnabled: true
//            )
//            let subId = try opcua.createSubscription(subscription: subscription).wait()
////            let itemsToCreate: [MonitoredItemCreateRequest] = [
////                MonitoredItemCreateRequest(
////                    itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20045)),
////                    requestedParameters: MonitoringParameters(clientHandle: 1, samplingInterval: 250)
////                )
////            ]
//            let results = try opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: itemsToCreate).wait()
//            results.forEach { result in
//                print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
//            }
//            
//            DispatchQueue.global().async {
//                sleep(2)
//                opcua.write(nodes: [
//                    WriteValue(
//                        nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20485),
//                        value: DataValue(variant: Variant(value: Int32(1)))
//                    )
//                ]).whenSuccess { writed in
//                    print("writed: 1")
//                }
//                sleep(4)
//                opcua.write(nodes: [
//                    WriteValue(
//                        nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20485),
//                        value: DataValue(variant: Variant(value: Int32(2)))
//                    )
//                ]).whenSuccess { writed in
//                    print("writed: 2")
//                }
//            }

sleep(10)
    
try opcua.disconnect(deleteSubscriptions: true).wait()

try eventLoopGroup.syncShutdownGracefully()

