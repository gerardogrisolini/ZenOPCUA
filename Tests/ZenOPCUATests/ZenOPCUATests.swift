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
        var count = 0
        let expectation = XCTestExpectation(description: "OPCUA")

        let opcua = ZenOPCUA(
            endpoint: "opc.tcp://MacBook-Pro-di-Gerardo.local:53530/OPCUA/SimulationServer",
            reconnect: false,
            eventLoopGroup: eventLoopGroup
        )
        
        let nodes: [ReadValue] = [
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2258), monitoredId: 1),
            ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Counter"), monitoredId: 2),
            ReadValue(nodeId: NodeIdString(nameSpace: 5, identifier: "MyLevel"), monitoredId: 3)
        ]
        opcua.onDataChanged = { data in
            data.forEach { dataChange in
                dataChange.dataChangeNotification.monitoredItems.forEach { item in
                    if let node = nodes.first(where: { $0.monitoredId == item.monitoredId }) {
                        print("\(node.nodeId): \(item.value.variant.value)")
                    }
                }
            }
            
            if count > 5 {
                XCTAssertTrue(count > 0)
                expectation.fulfill()
            }
            count += 1
        }
        opcua.onHandlerRemoved = {
            print("OPCUA Client disconnected")
        }
        opcua.onErrorCaught = { error in
            print(error)
        }
        
        do {
            try opcua.connect().wait()
            
//            let nodes: [BrowseDescription] = [
//                BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253)),
//                BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2256))
//            ]
//            let items = try opcua.browse(nodes: nodes).wait()
//            for item in items {
//                item.references.forEach { ref in
//                    print("\(ref.displayName.text): \(ref.nodeId)")
//                }
//            }

            let subId = try opcua.createSubscription(requestedPubliscingInterval: 500, startPubliscing: true).wait()
            let results = try opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: nodes).wait()
            results.forEach { result in
                print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
            }

            wait(for: [expectation], timeout: 10.0)

            let deleted = try opcua.deleteSubscriptions(subscriptionIds: [subId]).wait()
            deleted.forEach { result in
                print("deleteSubscription: \(result)")
            }

//            let reads = [ReadValue(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2258))]
//            let readed = try opcua.read(nodes: reads).wait()
//            print(readed.first?.variant.value ?? "nil")

//            let writes: [WriteValue] = [
//                WriteValue(
//                    nodeId: NodeIdString(nameSpace: 5, identifier: "MyLevel"),
//                    value: DataValue(variant: Variant(value: Double(21.0)))
//                )
//            ]
//            let writed = try opcua.write(nodes: writes).wait()
//            print(writed.first!)

            try opcua.disconnect().wait()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    static var allTests = [
        ("testExample", testExample)
    ]
}
