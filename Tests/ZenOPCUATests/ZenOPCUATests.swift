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
            ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Counter"), monitoredId: 2)
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

//            let writes = [
//                WriteValue(
//                    nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20053),
//                    value: DataValue(variant: Variant(value: UInt32(1)))
//                )
//            ]
//            let writed = try opcua.write(nodes: writes).wait()
//            print(writed.first!)

            try opcua.disconnect().wait()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEmpty() {
        let empty: [UInt8] = [0xff, 0xff, 0xff, 0xff]
        let number = UInt32(bytes: empty)
        XCTAssertEqual(number, UInt32.max)
    }
    
    func testGetEndPointsResponse() {
        let response = GetEndpointsResponse(bytes: getEndPointsResponse)
        XCTAssertTrue(response.endpoints.count > 0)
        print("Endpoints found: \(response.endpoints.count)")
        response.endpoints.forEach { item in
            print("... \(item.endpointUrl)")
            print("... \(item.server.applicationName.text)")
        }
    }

    func testCreateSessionResponse() {
        let response = CreateSessionResponse(bytes: createSessionResponse)
        XCTAssertTrue(response.serverEndpoints.first!.userIdentityTokens.count > 0)
        XCTAssertTrue(response.serverEndpoints.first!.endpointUrl.count > 0)
    }

    func testBrowseResponse() {
        let response = BrowseResponse(bytes: browseResponse)
        print("Endpoints found: \(response.results.count)")
        response.results.forEach { item in
            print("... \(item.statusCode)")
            item.references.forEach { ref in
                print("... \(ref.displayName.text)")
            }
        }
        XCTAssertTrue(response.results.count > 0)
    }

    func testReadResponse() {
        let response = ReadResponse(bytes: readResponse)
        print("Reads found: \(response.results.count)")
        response.results.forEach { item in
            print("... \(item.variant.value)")
        }
        XCTAssertTrue(response.results.count > 0)
    }

    func testPublishResponse() {
        let response = PublishResponse(bytes: publishResponse)
        response.notificationMessage.notificationData.forEach { item in
            item.dataChangeNotification.monitoredItems.forEach { m in
                print("... \(m.value.variant.value)")
            }
        }
        XCTAssertTrue(response.responseHeader.serviceResult == .UA_STATUSCODE_GOOD)
    }
    
    @available(OSX 10.12, *)
    func testTimestamp() {
//        let calendar = Calendar.current
//        let dstComponents = DateComponents(year: 1601,
//            month: 1,
//            day: 1)
//
//        let interval = DateInterval(start: calendar.date(from: dstComponents)!, end: Date())
//        let ti = Int64(interval.duration)
//        let ms = ti * 1000
//        print(ms)

        let bytes: [UInt8] = [
            //0xd8, 0x02, 0xfe, 0xc2, 0x07, 0xe9, 0xd5, 0x01
            0x00, 0x00, 0x00, 0x00, 0x80, 0x4f, 0x32, 0x41
        ]
        let data2 = Double(bytes: bytes)
        print(data2)
    }
    
    static var allTests = [
        ("testExample", testExample)
    ]

    let browseResponse: [UInt8] = [
        //0x4d, 0x53, 0x47, 0x46, 0xdf, 0x00, 0x00, 0x00,
        0xfd, 0x65, 0x00, 0x00, 0xeb, 0x5d, 0x01, 0x00,
        0x05, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x12, 0x02, 0x30, 0x97, 0x0e, 0x80,
        0x6b, 0xe9, 0xd5, 0x01, 0x05, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
        0xff, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
        0x03, 0x00, 0x00, 0x00, 0x00, 0x28, 0x01, 0x00,
        0x3d, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x46,
        0x6f, 0x6c, 0x64, 0x65, 0x72, 0x54, 0x79, 0x70,
        0x65, 0x03, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00,
        0x00, 0x00, 0x46, 0x6f, 0x6c, 0x64, 0x65, 0x72,
        0x54, 0x79, 0x70, 0x65, 0x08, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x23, 0x01, 0x01, 0x00, 0xcd,
        0x08, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x53,
        0x65, 0x72, 0x76, 0x65, 0x72, 0x03, 0x00, 0x00,
        0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x53, 0x65,
        0x72, 0x76, 0x65, 0x72, 0x01, 0x00, 0x00, 0x00,
        0x01, 0x00, 0xd4, 0x07, 0x00, 0x23, 0x01, 0x03,
        0x01, 0x00, 0x09, 0x00, 0x00, 0x00, 0x43, 0x6f,
        0x75, 0x6e, 0x74, 0x72, 0x69, 0x65, 0x73, 0x01,
        0x00, 0x09, 0x00, 0x00, 0x00, 0x43, 0x6f, 0x75,
        0x6e, 0x74, 0x72, 0x69, 0x65, 0x73, 0x03, 0x05,
        0x00, 0x00, 0x00, 0x65, 0x6e, 0x2d, 0x55, 0x53,
        0x09, 0x00, 0x00, 0x00, 0x43, 0x6f, 0x75, 0x6e,
        0x74, 0x72, 0x69, 0x65, 0x73, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x3d, 0xff, 0xff, 0xff, 0xff
    ]
    
    let createSessionResponse: [UInt8] = [
        //0x4d, 0x53, 0x47, 0x46, 0xd0, 0x01, 0x00, 0x00,
        0x24, 0x09, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x35, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
        0x01, 0x00, 0xd0, 0x01, 0x60, 0x8f, 0x53, 0xf0,
        0x40, 0xeb, 0xd5, 0x01, 0x02, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x00,
        0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x80, 0x4f,
        0x32, 0x41, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x01, 0x00, 0x00, 0x00, 0x1a, 0x00,
        0x00, 0x00, 0x6f, 0x70, 0x63, 0x2e, 0x74, 0x63,
        0x70, 0x3a, 0x2f, 0x2f, 0x31, 0x37, 0x32, 0x2e,
        0x31, 0x36, 0x2e, 0x31, 0x2e, 0x36, 0x33, 0x3a,
        0x34, 0x38, 0x34, 0x32, 0x29, 0x00, 0x00, 0x00,
        0x75, 0x72, 0x6e, 0x3a, 0x31, 0x37, 0x32, 0x2e,
        0x31, 0x36, 0x2e, 0x31, 0x2e, 0x36, 0x33, 0x3a,
        0x53, 0x33, 0x20, 0x4f, 0x50, 0x43, 0x2d, 0x55,
        0x41, 0x20, 0x45, 0x6d, 0x62, 0x65, 0x64, 0x64,
        0x65, 0x64, 0x20, 0x53, 0x65, 0x72, 0x76, 0x65,
        0x72, 0x19, 0x00, 0x00, 0x00, 0x53, 0x33, 0x20,
        0x4f, 0x50, 0x43, 0x2d, 0x55, 0x41, 0x20, 0x45,
        0x6d, 0x62, 0x65, 0x64, 0x64, 0x65, 0x64, 0x20,
        0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x02, 0x19,
        0x00, 0x00, 0x00, 0x53, 0x33, 0x20, 0x4f, 0x50,
        0x43, 0x2d, 0x55, 0x41, 0x20, 0x45, 0x6d, 0x62,
        0x65, 0x64, 0x64, 0x65, 0x64, 0x20, 0x53, 0x65,
        0x72, 0x76, 0x65, 0x72, 0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x01, 0x00, 0x00, 0x00, 0x1a, 0x00, 0x00, 0x00,
        0x6f, 0x70, 0x63, 0x2e, 0x74, 0x63, 0x70, 0x3a,
        0x2f, 0x2f, 0x31, 0x37, 0x32, 0x2e, 0x31, 0x36,
        0x2e, 0x31, 0x2e, 0x36, 0x33, 0x3a, 0x34, 0x38,
        0x34, 0x32, 0xff, 0xff, 0xff, 0xff, 0x01, 0x00,
        0x00, 0x00, 0x2f, 0x00, 0x00, 0x00, 0x68, 0x74,
        0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70, 0x63,
        0x66, 0x6f, 0x75, 0x6e, 0x64, 0x61, 0x74, 0x69,
        0x6f, 0x6e, 0x2e, 0x6f, 0x72, 0x67, 0x2f, 0x55,
        0x41, 0x2f, 0x53, 0x65, 0x63, 0x75, 0x72, 0x69,
        0x74, 0x79, 0x50, 0x6f, 0x6c, 0x69, 0x63, 0x79,
        0x23, 0x4e, 0x6f, 0x6e, 0x65, 0x02, 0x00, 0x00,
        0x00, 0x09, 0x00, 0x00, 0x00, 0x41, 0x6e, 0x6f,
        0x6e, 0x79, 0x6d, 0x6f, 0x75, 0x73, 0x00, 0x00,
        0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x08, 0x00,
        0x00, 0x00, 0x55, 0x73, 0x65, 0x72, 0x4e, 0x61,
        0x6d, 0x65, 0x01, 0x00, 0x00, 0x00, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x41, 0x00, 0x00, 0x00, 0x68, 0x74,
        0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70, 0x63,
        0x66, 0x6f, 0x75, 0x6e, 0x64, 0x61, 0x74, 0x69,
        0x6f, 0x6e, 0x2e, 0x6f, 0x72, 0x67, 0x2f, 0x55,
        0x41, 0x2d, 0x50, 0x72, 0x6f, 0x66, 0x69, 0x6c,
        0x65, 0x2f, 0x54, 0x72, 0x61, 0x6e, 0x73, 0x70,
        0x6f, 0x72, 0x74, 0x2f, 0x75, 0x61, 0x74, 0x63,
        0x70, 0x2d, 0x75, 0x61, 0x73, 0x63, 0x2d, 0x75,
        0x61, 0x62, 0x69, 0x6e, 0x61, 0x72, 0x79, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00
    ]

    let getEndPointsResponse: [UInt8] = [
        //0x4d, 0x53, 0x47, 0x46, 0xdf, 0x01, 0x00, 0x00,
        0xfd, 0x65, 0x00, 0x00, 0xeb, 0x5d, 0x01, 0x00,
        0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
        0x01, 0x00, 0xaf, 0x01, 0x10, 0xe5, 0x7d, 0x7e,
        0x6b, 0xe9, 0xd5, 0x01, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
        0xff, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x1f, 0x00, 0x00, 0x00, 0x6f, 0x70, 0x63, 0x2e,
        0x74, 0x63, 0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70,
        0x63, 0x75, 0x61, 0x73, 0x65, 0x72, 0x76, 0x65,
        0x72, 0x2e, 0x63, 0x6f, 0x6d, 0x3a, 0x34, 0x38,
        0x34, 0x38, 0x34, 0x1c, 0x00, 0x00, 0x00, 0x75,
        0x72, 0x6e, 0x3a, 0x75, 0x6e, 0x63, 0x6f, 0x6e,
        0x66, 0x69, 0x67, 0x75, 0x72, 0x65, 0x64, 0x3a,
        0x61, 0x70, 0x70, 0x6c, 0x69, 0x63, 0x61, 0x74,
        0x69, 0x6f, 0x6e, 0x14, 0x00, 0x00, 0x00, 0x68,
        0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70,
        0x65, 0x6e, 0x36, 0x32, 0x35, 0x34, 0x31, 0x2e,
        0x6f, 0x72, 0x67, 0x03, 0x02, 0x00, 0x00, 0x00,
        0x65, 0x6e, 0x22, 0x00, 0x00, 0x00, 0x6f, 0x70,
        0x65, 0x6e, 0x36, 0x32, 0x35, 0x34, 0x31, 0x2d,
        0x62, 0x61, 0x73, 0x65, 0x64, 0x20, 0x4f, 0x50,
        0x43, 0x20, 0x55, 0x41, 0x20, 0x41, 0x70, 0x70,
        0x6c, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e,
        0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x01, 0x00, 0x00, 0x00,
        0x2f, 0x00, 0x00, 0x00, 0x68, 0x74, 0x74, 0x70,
        0x3a, 0x2f, 0x2f, 0x6f, 0x70, 0x63, 0x66, 0x6f,
        0x75, 0x6e, 0x64, 0x61, 0x74, 0x69, 0x6f, 0x6e,
        0x2e, 0x6f, 0x72, 0x67, 0x2f, 0x55, 0x41, 0x2f,
        0x53, 0x65, 0x63, 0x75, 0x72, 0x69, 0x74, 0x79,
        0x50, 0x6f, 0x6c, 0x69, 0x63, 0x79, 0x23, 0x4e,
        0x6f, 0x6e, 0x65, 0x02, 0x00, 0x00, 0x00, 0x1a,
        0x00, 0x00, 0x00, 0x6f, 0x70, 0x65, 0x6e, 0x36,
        0x32, 0x35, 0x34, 0x31, 0x2d, 0x61, 0x6e, 0x6f,
        0x6e, 0x79, 0x6d, 0x6f, 0x75, 0x73, 0x2d, 0x70,
        0x6f, 0x6c, 0x69, 0x63, 0x79, 0x00, 0x00, 0x00,
        0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0x19, 0x00, 0x00,
        0x00, 0x6f, 0x70, 0x65, 0x6e, 0x36, 0x32, 0x35,
        0x34, 0x31, 0x2d, 0x75, 0x73, 0x65, 0x72, 0x6e,
        0x61, 0x6d, 0x65, 0x2d, 0x70, 0x6f, 0x6c, 0x69,
        0x63, 0x79, 0x01, 0x00, 0x00, 0x00, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x2f, 0x00,
        0x00, 0x00, 0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f,
        0x2f, 0x6f, 0x70, 0x63, 0x66, 0x6f, 0x75, 0x6e,
        0x64, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x2e, 0x6f,
        0x72, 0x67, 0x2f, 0x55, 0x41, 0x2f, 0x53, 0x65,
        0x63, 0x75, 0x72, 0x69, 0x74, 0x79, 0x50, 0x6f,
        0x6c, 0x69, 0x63, 0x79, 0x23, 0x4e, 0x6f, 0x6e,
        0x65, 0x41, 0x00, 0x00, 0x00, 0x68, 0x74, 0x74,
        0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70, 0x63, 0x66,
        0x6f, 0x75, 0x6e, 0x64, 0x61, 0x74, 0x69, 0x6f,
        0x6e, 0x2e, 0x6f, 0x72, 0x67, 0x2f, 0x55, 0x41,
        0x2d, 0x50, 0x72, 0x6f, 0x66, 0x69, 0x6c, 0x65,
        0x2f, 0x54, 0x72, 0x61, 0x6e, 0x73, 0x70, 0x6f,
        0x72, 0x74, 0x2f, 0x75, 0x61, 0x74, 0x63, 0x70,
        0x2d, 0x75, 0x61, 0x73, 0x63, 0x2d, 0x75, 0x61,
        0x62, 0x69, 0x6e, 0x61, 0x72, 0x79, 0x00
    ]
    
    var readResponse: [UInt8] = [
        //0x4d, 0x53, 0x47, 0x46, 0x51, 0x00, 0x00, 0x00,
        0x27, 0x09, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x37, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x7a, 0x02, 0x80, 0xfd, 0x19, 0xbf,
        0x45, 0xeb, 0xd5, 0x01, 0x05, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x05, 0x0c, 0x07, 0x00, 0x00, 0x00, 0x36, 0x32,
        0x31, 0x31, 0x32, 0x39, 0x38, 0x80, 0xfd, 0x19,
        0xbf, 0x45, 0xeb, 0xd5, 0x01, 0x00, 0x00, 0x00,
        0x00
    ]
    
    var publishResponse: [UInt8] = [
        //0x4d, 0x53, 0x47, 0x46, 0x88, 0x00, 0x00, 0x00,
        0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0xf3, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x3d, 0x03, 0x00, 0x4e, 0x22, 0x76,
        0x66, 0xef, 0xd5, 0x01, 0x07, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
        0xff, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x4e, 0x22,
        0x76, 0x66, 0xef, 0xd5, 0x01, 0x01, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x2b, 0x03, 0x01, 0x26, 0x00,
        0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x0d, 0x0d, 0x40, 0xb3, 0xc3, 0x75,
        0x66, 0xef, 0xd5, 0x01, 0x40, 0xb3, 0xc3, 0x75,
        0x66, 0xef, 0xd5, 0x01, 0xf0, 0x26, 0x22, 0x76,
        0x66, 0xef, 0xd5, 0x01, 0xff, 0xff, 0xff, 0xff,
        0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff
    ]
}
