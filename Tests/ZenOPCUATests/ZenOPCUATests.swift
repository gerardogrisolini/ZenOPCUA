import XCTest
import NIO
@testable import ZenOPCUA

final class ZenOPCUATests: XCTestCase {
    var eventLoopGroup: MultiThreadedEventLoopGroup!
    
    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }
    
    override func tearDown() {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func testExample() {

        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://127.0.0.1:4842",
            messageSecurityMode: .none,
            securityPolicy: .none
        )
        
        opcua.onHandlerActivated = {
            print("OPCUA Client activated")
        }
        opcua.onHandlerRemoved = {
            print("OPCUA Client disconnected")
        }
        opcua.onErrorCaught = { error in
            print("Error: \(error)")
        }
        
        opcua.onDataChanged = { data in
            data.forEach { dataChange in
                dataChange.dataChangeNotification.monitoredItems.forEach { item in
                    print("read: \(item.value.variant.value)")
                }
            }
        }

        do {
            try opcua.connect(reconnect: true).wait()
            
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

//            let reads = [ReadValue(nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20045))]
//            let readed = try opcua.read(nodes: reads).wait()
//            print(readed.first?.variant.value ?? "nil")


            let subscription = Subscription(
                requestedPubliscingInterval: 100,
                publishingEnabled: true
            )
            let subId = try opcua.createSubscription(subscription: subscription).wait()
            let itemsToCreate: [MonitoredItemCreateRequest] = [
                MonitoredItemCreateRequest(
                    itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20485)),
                    requestedParameters: MonitoringParameters()
                )
            ]
            let results = try opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: itemsToCreate).wait()
            results.forEach { result in
                print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
            }
            
            DispatchQueue.global().async {
                sleep(20)
                opcua.write(nodes: [
                    WriteValue(
                        nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20485),
                        value: DataValue(variant: Variant(value: Int32(1)))
                    )
                ]).whenSuccess { writed in
                    print("writed: 1")
                }
                sleep(20)
                opcua.write(nodes: [
                    WriteValue(
                        nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20485),
                        value: DataValue(variant: Variant(value: Int32(2)))
                    )
                ]).whenSuccess { writed in
                    print("writed: 2")
                }
            }

            sleep(60 * 15)
            
            try opcua.disconnect(deleteSubscriptions: true).wait()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPublishResponse() {
        let bytes: [UInt8] = [
            145, 244, 43, 83, 1, 0, 0, 0, 52, 0, 0, 0, 3, 0, 0, 0, 1, 0, 175, 1, 156, 62, 225, 70, 67, 140, 214, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 26, 0, 0, 0, 111, 112, 99, 46, 116, 99, 112, 58, 47, 47, 49, 48, 46, 49, 48, 46, 53, 55, 46, 54, 51, 58, 52, 56, 52, 50, 38, 0, 0, 0, 117, 114, 110, 58, 49, 48, 46, 49, 48, 46, 53, 55, 46, 54, 51, 58, 79, 80, 67, 45, 85, 65, 32, 69, 109, 98, 101, 100, 100, 101, 100, 32, 83, 101, 114, 118, 101, 114, 22, 0, 0, 0, 79, 80, 67, 45, 85, 65, 32, 69, 109, 98, 101, 100, 100, 101, 100, 32, 83, 101, 114, 118, 101, 114, 2, 22, 0, 0, 0, 79, 80, 67, 45, 85, 65, 32, 69, 109, 98, 101, 100, 100, 101, 100, 32, 83, 101, 114, 118, 101, 114, 2, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 1, 0, 0, 0, 26, 0, 0, 0, 111, 112, 99, 46, 116, 99, 112, 58, 47, 47, 49, 48, 46, 49, 48, 46, 53, 55, 46, 54, 51, 58, 52, 56, 52, 50, 255, 255, 255, 255, 1, 0, 0, 0, 47, 0, 0, 0, 104, 116, 116, 112, 58, 47, 47, 111, 112, 99, 102, 111, 117, 110, 100, 97, 116, 105, 111, 110, 46, 111, 114, 103, 47, 85, 65, 47, 83, 101, 99, 117, 114, 105, 116, 121, 80, 111, 108, 105, 99, 121, 35, 78, 111, 110, 101, 2, 0, 0, 0, 9, 0, 0, 0, 65, 110, 111, 110, 121, 109, 111, 117, 115, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 8, 0, 0, 0, 85, 115, 101, 114, 78, 97, 109, 101, 1, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 65, 0, 0, 0, 104, 116, 116, 112, 58, 47, 47, 111, 112, 99, 102, 111, 117, 110, 100, 97, 116, 105, 111, 110, 46, 111, 114, 103, 47, 85, 65, 45, 80, 114, 111, 102, 105, 108, 101, 47, 84, 114, 97, 110, 115, 112, 111, 114, 116, 47, 117, 97, 116, 99, 112, 45, 117, 97, 115, 99, 45, 117, 97, 98, 105, 110, 97, 114, 121, 0
        ]
        
        let p = GetEndpointsResponse(bytes: bytes)
        XCTAssertTrue(p.endpoints.count > 0)
    }
    
    
    static var allTests = [
        ("testExample", testExample),
        ("testPublishResponse", testPublishResponse)
    ]
}
