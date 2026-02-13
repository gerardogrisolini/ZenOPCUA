import XCTest
import NIO
@testable import ZenOPCUA

final class ZenOPCUATests: XCTestCase {
    var eventLoopGroup: MultiThreadedEventLoopGroup!
    
    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    }
    
    override func tearDown() {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    func testConnection() throws {
        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://Gerardos-MacBook-Pro.local:53530/OPCUA/SimulationServer", //"opc.tcp://opcuaserver.com:48010",
            messageSecurityMode: .none,
            securityPolicy: .none
        )

        opcua.onHandlerActivated = {
            print("Client activated")
        }
        opcua.onHandlerRemoved = {
            print("Client disconnected")
        }
        opcua.onErrorCaught = { error in
            print("Error: \(error)")
        }
        
        opcua.onDataChanged = { data in
            data.forEach { dataChange in
                dataChange.dataChangeNotification.monitoredItems.forEach { item in
                    print(item.value.variant.value)
                }
            }
        }

        // Connect
        try opcua.connect(reconnect: false).wait()
        
        // Browse
        let root: [BrowseDescription] = [
            BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253))
        ]
        let nodes = try opcua.browse(nodes: root).wait()
        for item in nodes {
            item.references.forEach { ref in
                print("\(ref.displayName.text): \(ref.nodeId)")
            }
        }
        
        // Subscription
        let subscription = Subscription(
            requestedPubliscingInterval: 1000,
            requestedLifetimeCount: 1000,
            requesteMaxKeepAliveCount: 12,
            maxNotificationsPerPublish: 0,
            publishingEnabled: true
        )
        let subId = try opcua.createSubscription(subscription: subscription, startPublishing: true).wait()
        let itemsToCreate: [MonitoredItemCreateRequest] = [
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1001)), // "Counter"
                requestedParameters: MonitoringParameters(clientHandle: 1, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1002)), // "Random"
                requestedParameters: MonitoringParameters(clientHandle: 3, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1003)), // "Sawtooth"
                requestedParameters: MonitoringParameters(clientHandle: 4, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1004)), // "Sinusoid"
                requestedParameters: MonitoringParameters(clientHandle: 5, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1005)), // "Square"
                requestedParameters: MonitoringParameters(clientHandle: 6, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1006)), // "Triangle"
                requestedParameters: MonitoringParameters(clientHandle: 7, samplingInterval: 250)
            )
        ]
        
        let results = try opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: itemsToCreate).wait()
        results.forEach { result in
            print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
        }

        sleep(5)

        let deleted = try opcua.deleteSubscriptions(subscriptionIds: [subId]).wait()
        deleted.forEach { result in
            print("deleteSubscription: \(result)")
        }

        // Read
        let reads = [
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1001)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1002)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1003)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1004)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1005)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1006)),
        ]

        for i in 0..<1 {
            let readed = try opcua.read(nodes: reads).wait()
            readed.forEach { dataValue in
                print("dataValue sync(\(i): \(dataValue.variant.value) = \(dataValue.variant.type))")
            }
        }
        
        // Write
        let writed = try opcua.write(nodes: [
            WriteValue(
                nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20222),
                value: DataValue(variant: Variant(value: Int32(1)))
            )
        ]).wait()
        print("writed: \(writed.count)")

        try opcua.disconnect(deleteSubscriptions: true).wait()
    }
    
    func testConnectionAsync() async throws {
        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://Gerardos-MacBook-Pro.local:53530/OPCUA/SimulationServer", //"opc.tcp://opcuaserver.com:48010",
            messageSecurityMode: .signAndEncrypt,
            securityPolicy: .basic256Sha256,
            certificate: "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-cert.pem",
            privateKey: "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-key-rsa.pem"
        )

        opcua.onHandlerActivated = {
            print("Client activated")
        }
        opcua.onHandlerRemoved = {
            print("Client disconnected")
        }
        opcua.onErrorCaught = { error in
            print("Error: \(error)")
        }
        
        opcua.onDataChanged = { data in
            data.forEach { dataChange in
                dataChange.dataChangeNotification.monitoredItems.forEach { item in
                    print(item.value.variant.value)
                }
            }
        }

        // Connect
        try await opcua.connect(reconnect: false)
        
        // Browse
        let root: [BrowseDescription] = [
            BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253))
        ]
        let nodes = try await opcua.browse(nodes: root)
        for item in nodes {
            item.references.forEach { ref in
                print("\(ref.displayName.text): \(ref.nodeId)")
            }
        }
        
        // Subscription
        let subscription = Subscription(
            requestedPubliscingInterval: 1000,
            requestedLifetimeCount: 1000,
            requesteMaxKeepAliveCount: 12,
            maxNotificationsPerPublish: 0,
            publishingEnabled: true
        )
        let subId = try await opcua.createSubscription(subscription: subscription, startPublishing: true)
        let itemsToCreate: [MonitoredItemCreateRequest] = [
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1001)), // "Counter"
                requestedParameters: MonitoringParameters(clientHandle: 1, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1002)), // "Random"
                requestedParameters: MonitoringParameters(clientHandle: 3, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1003)), // "Sawtooth"
                requestedParameters: MonitoringParameters(clientHandle: 4, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1004)), // "Sinusoid"
                requestedParameters: MonitoringParameters(clientHandle: 5, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1005)), // "Square"
                requestedParameters: MonitoringParameters(clientHandle: 6, samplingInterval: 250)
            ),
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1006)), // "Triangle"
                requestedParameters: MonitoringParameters(clientHandle: 7, samplingInterval: 250)
            )
        ]
        let results = try await opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: itemsToCreate)
        results.forEach { result in
            print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
        }

        try await Task.sleep(nanoseconds: 5_000_000_000)

        let deleted = try await opcua.deleteSubscriptions(subscriptionIds: [subId])
        deleted.forEach { result in
            print("deleteSubscription: \(result)")
        }

        
        // Read
        let reads = [
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1001)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1002)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1003)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1004)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1005)),
            ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1006)),
        ]

        for i in 0..<1 {
            let readed = try await opcua.read(nodes: reads)
            readed.forEach { dataValue in
                print("dataValue sync(\(i): \(dataValue.variant.value) = \(dataValue.variant.type))")
            }
        }
        
        // Write
        opcua.write(nodes: [
            WriteValue(
                nodeId: NodeIdNumeric(nameSpace: 2, identifier: 20222),
                value: DataValue(variant: Variant(value: Int32(1)))
            )
        ]).whenSuccess { writed in
            print("writed: 1")
        }

        try await opcua.disconnect(deleteSubscriptions: true)
    }

    func testConnectionWithSing() async throws {
        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://Gerardos-MacBook-Pro.local:53530/OPCUA/SimulationServer",
            messageSecurityMode: .sign,
            securityPolicy: .basic256Sha256,
            certificate: "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-cert.pem",
            privateKey: "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-key-rsa.pem"
        )

        try await opcua.connect(reconnect: false)
        let root: [BrowseDescription] = [
            BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253))
        ]
        let nodes = try await opcua.browse(nodes: root)
        for item in nodes {
            item.references.forEach { ref in
                print("\(ref.displayName.text): \(ref.nodeId)")
            }
        }
        try await opcua.disconnect(deleteSubscriptions: false)
    }

    func testConnectionWithUsernamePassword() async throws {
        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://Gerardos-MacBook-Pro.local:53530/OPCUA/SimulationServer",
//            messageSecurityMode: .none,
//            securityPolicy: .none,
            messageSecurityMode: .signAndEncrypt,
            securityPolicy: .basic256Sha256,
            certificate: "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-cert.pem",
            privateKey: "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-key-rsa.pem"
        )

        try await opcua.connect(username: "zen-opcua", password: "opcua", reconnect: false)
        let root: [BrowseDescription] = [
            BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253))
        ]
        let nodes = try await opcua.browse(nodes: root)
        for item in nodes {
            item.references.forEach { ref in
                print("\(ref.displayName.text): \(ref.nodeId)")
            }
        }
        try await opcua.disconnect(deleteSubscriptions: false)
    }
    
    static let allTests = [
        ("testConnection", testConnection),
        ("testConnectionAsync", testConnectionAsync),
        ("testConnectionWithSing", testConnectionWithSing),
        ("testConnectionWithUsernamePassword", testConnectionWithUsernamePassword)
    ]
}
