import XCTest
import NIO
@testable import ZenOPCUA

final class ZenOPCUATests: XCTestCase {
    var eventLoopGroup: MultiThreadedEventLoopGroup!
    
    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    }
    
    override func tearDown() {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func testExample() {
//        let opcua = ZenOPCUA(
//            eventLoopGroup: eventLoopGroup,
//            endpointUrl: "opc.tcp://MacBook-Pro-di-Gerardo.local:4842/OPCUA/SimulationServer",
//            messageSecurityMode: .none,
//            securityPolicy: .none
//        )

        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://MacBook-Pro-di-Gerardo.local:4842/OPCUA/SimulationServer",
            messageSecurityMode: .signAndEncrypt,
            securityPolicy: .basic256,
            certificate: "/Users/gerardo/Projects/Zen/ZenOPCUA/certificates/certificate.crt",
            privateKey: "/Users/gerardo/Projects/Zen/ZenOPCUA/certificates/private.key"
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
                print("*****************")
                dataChange.dataChangeNotification.monitoredItems.forEach { item in
                    print("\(item.value.variant.value) - \(item.value.serverTimestamp)")
                }
            }
        }

        do {
            try opcua.connect(reconnect: false).wait()
            sleep(15)
            

//            let root: [BrowseDescription] = [
//                BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253))
//            ]
//            let nodes = try opcua.browse(nodes: root).wait()
//            for item in nodes {
//                item.references.forEach { ref in
//                    print("\(ref.displayName.text): \(ref.nodeId)")
//                }
//            }
            
//            let deleted = try opcua.deleteSubscriptions(subscriptionIds: [subId]).wait()
//            deleted.forEach { result in
//                print("deleteSubscription: \(result)")
//            }
            
//            let subscription = Subscription(
//                requestedPubliscingInterval: 100,
//                publishingEnabled: true
//            )
//            let subId = try opcua.createSubscription(subscription: subscription, startPublishing: true).wait()
//            let itemsToCreate: [MonitoredItemCreateRequest] = [
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Counter")),
//                    requestedParameters: MonitoringParameters(clientHandle: 1, samplingInterval: 250)
//                ),
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Expression")),
//                    requestedParameters: MonitoringParameters(clientHandle: 2, samplingInterval: 250)
//                ),
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Random")),
//                    requestedParameters: MonitoringParameters(clientHandle: 3, samplingInterval: 250)
//                ),
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Sawtooth")),
//                    requestedParameters: MonitoringParameters(clientHandle: 4, samplingInterval: 250)
//                ),
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Sinusoid")),
//                    requestedParameters: MonitoringParameters(clientHandle: 5, samplingInterval: 250)
//                ),
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Square")),
//                    requestedParameters: MonitoringParameters(clientHandle: 6, samplingInterval: 250)
//                ),
//                MonitoredItemCreateRequest(
//                    itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Triangle")),
//                    requestedParameters: MonitoringParameters(clientHandle: 7, samplingInterval: 250)
//                )
//            ]
//            let results = try opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: itemsToCreate).wait()
//            results.forEach { result in
//                print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
//            }
//
//            let reads = [
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Counter")),
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Expression")),
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Random")),
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Sawtooth")),
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Sinusoid")),
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Square")),
//                ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Triangle"))
//            ]
            
//            DispatchQueue.global().async {
//                opcua.isBusy = true

//                for i in 0...5 {
//                    let readed = try! opcua.read(nodes: reads).wait()
//                    readed.forEach { dataValue in
//                        print("dataValue sync(\(i): \(dataValue.variant.value)")
//                    }
//                }

//                var futures = [EventLoopFuture<[DataValue]>]()
//                for _ in 0...100 {
//                    futures.append(opcua.read(nodes: reads))
//                }
//                let readeds: EventLoopFuture<[[DataValue]]> = EventLoopFuture.whenAllSucceed(futures, on: self.eventLoopGroup.next())
//                readeds.whenSuccess { readeds in
//                    var n = 0
//                    for readed in readeds {
//                        n += 1
//                        readed.forEach { dataValue in
//                            print("dataValue async(\(n)): \(dataValue.variant.value)")
//                        }
//                    }
//                }
//                readeds.whenFailure { error in
//                    print("dataValue error = \(error)")
//                }
//
//                opcua.isBusy = false
//            }
            
//            DispatchQueue.global().async {
//                sleep(5)
//                opcua.write(nodes: [
//                    WriteValue(
//                        nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20222),
//                        value: DataValue(variant: Variant(value: Int32(1)))
//                    )
//                ]).whenSuccess { writed in
//                    print("writed: 1")
//                }
//                sleep(7)
//                opcua.write(nodes: [
//                    WriteValue(
//                        nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20485),
//                        value: DataValue(variant: Variant(value: Int32(2)))
//                    )
//                ]).whenSuccess { writed in
//                    print("writed: 2")
//                }
//            }
             
            XCTAssertNoThrow(try opcua.disconnect(deleteSubscriptions: false).wait())
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testPublishResponse() {
        let bytes: [UInt8] = [
            18, 0, 0, 0, 51, 0, 0, 0, 104, 116, 116, 112, 58, 47, 47, 111, 112, 99, 102, 111, 117, 110, 100, 97, 116, 105, 111, 110, 46, 111, 114, 103, 47, 85, 65, 47, 83, 101, 99, 117, 114, 105, 116, 121, 80, 111, 108, 105, 99, 121, 35, 66, 97, 115, 105, 99, 50, 53, 54, 75, 4, 0, 0, 48, 130, 4, 71, 48, 130, 3, 47, 160, 3, 2, 1, 2, 2, 6, 1, 116, 157, 108, 43, 32, 48, 13, 6, 9, 42, 134, 72, 134, 247, 13, 1, 1, 11, 5, 0, 48, 117, 49, 48, 48, 46, 6, 3, 85, 4, 3, 12, 39, 83, 105, 109, 117, 108, 97, 116, 105, 111, 110, 83, 101, 114, 118, 101, 114, 64, 77, 97, 99, 66, 111, 111, 107, 45, 80, 114, 111, 45, 100, 105, 45, 71, 101, 114, 97, 114, 100, 111, 49, 19, 48, 17, 6, 3, 85, 4, 10, 12, 10, 80, 114, 111, 115, 121, 115, 32, 79, 80, 67, 49, 44, 48, 42, 6, 10, 9, 146, 38, 137, 147, 242, 44, 100, 1, 25, 22, 28, 77, 97, 99, 66, 111, 111, 107, 45, 80, 114, 111, 45, 100, 105, 45, 71, 101, 114, 97, 114, 100, 111, 46, 108, 111, 99, 97, 108, 48, 30, 23, 13, 50, 48, 48, 57, 49, 55, 49, 55, 53, 53, 52, 53, 90, 23, 13, 51, 48, 48, 57, 49, 53, 49, 56, 53, 53, 52, 53, 90, 48, 117, 49, 48, 48, 46, 6, 3, 85, 4, 3, 12, 39, 83, 105, 109, 117, 108, 97, 116, 105, 111, 110, 83, 101, 114, 118, 101, 114, 64, 77, 97, 99, 66, 111, 111, 107, 45, 80, 114, 111, 45, 100, 105, 45, 71, 101, 114, 97, 114, 100, 111, 49, 19, 48, 17, 6, 3, 85, 4, 10, 12, 10, 80, 114, 111, 115, 121, 115, 32, 79, 80, 67, 49, 44, 48, 42, 6, 10, 9, 146, 38, 137, 147, 242, 44, 100, 1, 25, 22, 28, 77, 97, 99, 66, 111, 111, 107, 45, 80, 114, 111, 45, 100, 105, 45, 71, 101, 114, 97, 114, 100, 111, 46, 108, 111, 99, 97, 108, 48, 130, 1, 34, 48, 13, 6, 9, 42, 134, 72, 134, 247, 13, 1, 1, 1, 5, 0, 3, 130, 1, 15, 0, 48, 130, 1, 10, 2, 130, 1, 1, 0, 171, 124, 63, 25, 3, 40, 238, 80, 174, 9, 197, 209, 249, 117, 220, 8, 96, 187, 41, 106, 0, 130, 207, 29, 157, 202, 64, 139, 222, 143, 11, 66, 139, 232, 112, 44, 205, 15, 178, 199, 29, 228, 36, 99, 95, 166, 253, 139, 123, 98, 158, 84, 118, 74, 183, 94, 187, 137, 141, 241, 188, 45, 34, 72, 12, 133, 58, 44, 188, 133, 101, 209, 85, 230, 45, 109, 217, 220, 99, 171, 118, 47, 178, 145, 111, 215, 9, 61, 162, 12, 161, 205, 125, 95, 0, 56, 226, 145, 90, 76, 30, 113, 54, 51, 198, 39, 255, 66, 28, 122, 119, 43, 48, 253, 15, 210, 172, 126, 123, 104, 155, 186, 91, 59, 22, 103, 220, 74, 10, 231, 154, 78, 178, 147, 4, 138, 83, 15, 131, 229, 233, 191, 88, 154, 153, 239, 50, 126, 51, 41, 54, 85, 143, 20, 193, 229, 230, 184, 4, 186, 138, 225, 251, 45, 66, 73, 234, 1, 185, 94, 0, 142, 59, 163, 85, 29, 86, 212, 8, 166, 236, 10, 78, 71, 116, 135, 126, 19, 81, 5, 199, 21, 193, 190, 239, 219, 60, 197, 7, 253, 183, 45, 178, 101, 154, 46, 68, 188, 182, 43, 251, 82, 233, 110, 222, 45, 176, 201, 146, 126, 159, 61, 161, 147, 21, 226, 136, 145, 198, 221, 11, 62, 249, 244, 87, 121, 84, 20, 138, 5, 121, 75, 83, 7, 123, 136, 195, 88, 22, 150, 17, 110, 17, 31, 110, 31, 2, 3, 1, 0, 1, 163, 129, 220, 48, 129, 217, 48, 31, 6, 3, 85, 29, 35, 4, 24, 48, 22, 128, 20, 50, 192, 236, 98, 194, 183, 83, 241, 210, 149, 75, 175, 125, 138, 101, 191, 157, 224, 195, 244, 48, 29, 6, 3, 85, 29, 14, 4, 22, 4, 20, 50, 192, 236, 98, 194, 183, 83, 241, 210, 149, 75, 175, 125, 138, 101, 191, 157, 224, 195, 244, 48, 9, 6, 3, 85, 29, 19, 4, 2, 48, 0, 48, 11, 6, 3, 85, 29, 15, 4, 4, 3, 2, 2, 244, 48, 29, 6, 3, 85, 29, 37, 4, 22, 48, 20, 6, 8, 43, 6, 1, 5, 5, 7, 3, 1, 6, 8, 43, 6, 1, 5, 5, 7, 3, 2, 48, 96, 6, 3, 85, 29, 17, 4, 89, 48, 87, 134, 55, 117, 114, 110, 58, 77, 97, 99, 66, 111, 111, 107, 45, 80, 114, 111, 45, 100, 105, 45, 71, 101, 114, 97, 114, 100, 111, 46, 108, 111, 99, 97, 108, 58, 79, 80, 67, 85, 65, 58, 83, 105, 109, 117, 108, 97, 116, 105, 111, 110, 83, 101, 114, 118, 101, 114, 130, 28, 77, 97, 99, 66, 111, 111, 107, 45, 80, 114, 111, 45, 100, 105, 45, 71, 101, 114, 97, 114, 100, 111, 46, 108, 111, 99, 97, 108, 48, 13, 6, 9, 42, 134, 72, 134, 247, 13, 1, 1, 11, 5, 0, 3, 130, 1, 1, 0, 136, 62, 189, 224, 149, 91, 199, 143, 7, 157, 92, 139, 43, 95, 64, 218, 42, 139, 183, 161, 57, 168, 114, 81, 87, 234, 130, 47, 37, 235, 105, 168, 172, 36, 152, 230, 118, 38, 157, 56, 167, 52, 39, 59, 253, 168, 20, 184, 70, 41, 242, 93, 255, 55, 84, 6, 145, 206, 73, 200, 175, 99, 221, 98, 228, 221, 120, 122, 167, 205, 64, 203, 234, 156, 120, 11, 149, 71, 222, 37, 58, 243, 125, 174, 228, 150, 36, 38, 17, 177, 24, 248, 146, 66, 174, 31, 103, 110, 142, 168, 3, 159, 56, 148, 12, 46, 251, 230, 163, 214, 232, 71, 28, 29, 242, 227, 86, 243, 48, 105, 78, 216, 84, 84, 40, 126, 150, 187, 160, 63, 40, 190, 29, 40, 171, 134, 36, 117, 74, 6, 104, 64, 8, 187, 18, 239, 20, 201, 63, 35, 68, 101, 233, 11, 142, 88, 32, 72, 196, 12, 104, 191, 124, 32, 180, 154, 62, 7, 82, 32, 153, 32, 81, 232, 175, 157, 174, 5, 190, 69, 142, 175, 232, 154, 117, 30, 6, 32, 225, 217, 152, 156, 122, 68, 45, 105, 129, 66, 223, 219, 132, 95, 252, 45, 23, 190, 21, 212, 67, 37, 190, 188, 211, 126, 29, 84, 112, 51, 173, 29, 90, 249, 47, 138, 184, 78, 151, 135, 2, 8, 188, 181, 205, 223, 103, 37, 10, 231, 1, 62, 244, 125, 126, 30, 174, 221, 73, 235, 147, 104, 136, 63, 34, 6, 119, 168, 20, 0, 0, 0, 152, 155, 15, 209, 213, 185, 235, 56, 193, 228, 134, 81, 136, 163, 129, 204, 180, 144, 186, 76, 29, 62, 68, 108, 65, 239, 154, 26, 74, 36, 177, 193, 127, 120, 25, 30, 230, 21, 139, 83, 82, 11, 7, 224, 108, 194, 21, 7, 36, 255, 168, 104, 135, 118, 49, 205, 242, 181, 133, 40, 54, 180, 128, 5, 237, 134, 13, 92, 151, 105, 108, 50, 235, 165, 40, 220, 32, 69, 110, 200, 250, 90, 208, 181, 132, 220, 243, 7, 240, 57, 180, 85, 73, 93, 144, 45, 40, 240, 91, 63, 136, 198, 161, 198, 4, 65, 56, 90, 13, 155, 159, 91, 105, 96, 52, 182, 69, 81, 153, 75, 164, 10, 32, 4, 56, 117, 79, 244, 182, 74, 44, 5, 80, 78, 131, 16, 153, 195, 231, 86, 232, 12, 75, 36, 178, 255, 252, 149, 176, 37, 131, 177, 112, 219, 49, 183, 89, 155, 15, 235, 102, 189, 241, 119, 156, 167, 116, 158, 74, 232, 235, 72, 109, 179, 122, 196, 70, 25, 124, 40, 22, 129, 153, 177, 115, 174, 15, 93, 164, 234, 206, 221, 129, 22, 84, 1, 101, 225, 134, 90, 58, 101, 102, 103, 227, 161, 5, 99, 180, 84, 10, 195, 168, 212, 235, 224, 163, 39, 85, 15, 3, 123, 129, 69, 163, 162, 32, 109, 134, 200, 198, 146, 73, 75, 233, 132, 117, 157, 91, 241, 0, 196, 88, 110, 117, 129, 133, 218, 139, 239, 243, 158, 236, 38, 27, 47, 16, 123, 236, 140, 229, 91, 9, 130, 144, 230, 113, 143, 241, 208, 20, 6, 100, 75, 147, 115, 55, 149, 220, 160, 84, 18, 221, 55, 178, 115, 212, 173, 9, 165, 110, 116, 50, 168, 152, 109, 219, 112, 25, 228, 179, 186, 158, 159, 175, 191, 61, 159, 24, 44, 166, 160, 192, 162, 190, 194, 112, 168, 187, 116, 34, 88, 168, 127, 91, 131, 121, 121, 224, 102, 229, 49, 173, 22, 218, 218, 3, 111, 30, 186, 125, 26, 185, 3, 119, 25, 80, 223, 2, 192, 249, 197, 249, 68, 103, 62, 151, 67, 212, 244, 160, 134, 17, 130, 146, 201, 228, 51, 75, 15, 56, 211, 191, 42, 71, 56, 138, 185, 230, 240, 183, 74, 148, 235, 64, 145, 207, 59, 103, 17, 16, 90, 57, 255, 8, 102, 242, 16, 92, 228, 114, 75, 28, 154, 137, 77, 198, 236, 233, 23, 111, 236, 235, 197, 56, 225, 150, 241, 205, 46, 122, 68, 65, 17, 91, 31, 36, 250, 247, 83, 31, 174, 0, 221, 72, 193, 228, 116, 33, 126, 199, 160, 130, 186, 214, 153, 122, 214, 68, 4, 55, 209, 117, 220, 173, 195, 160, 68, 193, 70, 35, 40, 59, 251, 109, 29, 176, 191, 65, 121, 29, 165, 182, 167, 185, 145, 99, 100, 47, 127, 28, 143, 134, 93, 58, 104, 187, 184, 53, 72, 181, 201, 108, 185, 244, 146, 143, 124, 206, 236, 227, 100, 126, 122, 130, 238, 174, 170, 128, 163, 239, 95, 71, 78, 138, 132, 15, 249, 86, 136, 199, 126, 236, 140, 85, 135, 78, 13, 225, 134, 102, 159
        ]
        
        //TODO: decrypt message
        
        
        let p = OpenSecureChannelResponse(bytes: bytes)
        XCTAssertTrue(p.responseHeader.requestHandle > 0)
    }
    
    
    static var allTests = [
        ("testExample", testExample),
        ("testPublishResponse", testPublishResponse)
    ]
}
