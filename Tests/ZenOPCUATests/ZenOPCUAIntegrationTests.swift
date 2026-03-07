import XCTest
import NIO
@testable import ZenOPCUA

final class ZenOPCUAIntegrationTests: XCTestCase {
    private enum IntegrationTestError: Error {
        case timeout
    }

    private let endpointUrl = "opc.tcp://Gerardos-MacBook-Pro.local:53530/OPCUA/SimulationServer"
    private let certificatePath = "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-cert.pem"
    private let privateKeyPath = "/Users/gerardo/Projects/ZenOPCUA/certificates/opcua-client-key-rsa.pem"
    private let rootNodeValue = NodeValue.numeric(nameSpace: 0, identifier: 2253)
    private let monitoredNodeValues: [NodeValue] = [
        .numeric(nameSpace: 3, identifier: 1001),
        .numeric(nameSpace: 3, identifier: 1002),
        .numeric(nameSpace: 3, identifier: 1003)
    ]
    private let writableNodeValue = NodeValue.numeric(nameSpace: 2, identifier: 20222)

    private var eventLoopGroup: MultiThreadedEventLoopGroup!

    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    }

    override func tearDown() {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    private func makeClient(
        messageSecurityMode: MessageSecurityMode = .none,
        securityPolicy: SecurityPolicies = .none
    ) -> ZenOPCUA {
        ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: endpointUrl,
            messageSecurityMode: messageSecurityMode,
            securityPolicy: securityPolicy,
            certificate: messageSecurityMode == .none ? nil : certificatePath,
            privateKey: messageSecurityMode == .none ? nil : privateKeyPath
        )
    }

    private func makeSubscription(startPublishing: Bool = false) -> Subscription {
        Subscription(
            requestedPubliscingInterval: 300,
            requestedLifetimeCount: 1000,
            requesteMaxKeepAliveCount: 12,
            maxNotificationsPerPublish: 0,
            publishingEnabled: startPublishing
        )
    }

    private func makeMonitoredItems() -> [MonitoredItemCreateRequest] {
        monitoredNodeValues.enumerated().map { index, nodeValue in
            MonitoredItemCreateRequest(
                itemToMonitor: ReadValue(nodeValue: nodeValue),
                requestedParameters: MonitoringParameters(
                    clientHandle: UInt32(index + 1),
                    samplingInterval: 250
                )
            )
        }
    }

    private func nextDataChanges(
        from stream: AsyncStream<[DataChange]>,
        timeoutNanoseconds: UInt64 = 8_000_000_000
    ) async throws -> [DataChange] {
        try await withThrowingTaskGroup(of: [DataChange].self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                guard let value = await iterator.next() else {
                    throw IntegrationTestError.timeout
                }
                return value
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw IntegrationTestError.timeout
            }

            let firstCompleted = try await group.next()
            group.cancelAll()
            return try XCTUnwrap(firstCompleted)
        }
    }

    private func connectAnonymousSync() throws -> ZenOPCUA {
        let opcua = makeClient()
        try opcua.connect(reconnect: false).wait()
        return opcua
    }

    private func connectAnonymousAsync() async throws -> ZenOPCUA {
        let opcua = makeClient()
        try await opcua.connect(reconnect: false)
        return opcua
    }

    private func connectSecureAsync(messageSecurityMode: MessageSecurityMode) async throws -> ZenOPCUA {
        let opcua = makeClient(
            messageSecurityMode: messageSecurityMode,
            securityPolicy: .basic256Sha256
        )
        try await opcua.connect(reconnect: false)
        return opcua
    }

    private func connectUsernamePasswordAsync() async throws -> ZenOPCUA {
        let opcua = makeClient(
            messageSecurityMode: .signAndEncrypt,
            securityPolicy: .basic256Sha256
        )
        try await opcua.connect(
            username: "zen-opcua",
            password: "opcua",
            reconnect: false
        )
        return opcua
    }

    private func disconnectAsync(_ opcua: ZenOPCUA, deleteSubscriptions: Bool) async {
        try? await opcua.disconnect(deleteSubscriptions: deleteSubscriptions)
    }

    func testConnection() throws {
        let opcua = try connectAnonymousSync()
        defer {
            try? opcua.disconnect(deleteSubscriptions: true).wait()
        }

        let explicitBrowse = try opcua.browse(
            nodes: [BrowseDescription(nodeValue: rootNodeValue)]
        ).wait()
        XCTAssertFalse(explicitBrowse.isEmpty)

        let nodeValueBrowse = try opcua.browse(nodeValues: [rootNodeValue]).wait()
        XCTAssertEqual(nodeValueBrowse.count, 1)
        XCTAssertFalse(nodeValueBrowse[0].references.isEmpty)

        let defaultBrowse = try opcua.browse().wait()
        XCTAssertFalse(defaultBrowse.isEmpty)

        let reads = try opcua.read(nodeValues: monitoredNodeValues).wait()
        XCTAssertEqual(reads.count, monitoredNodeValues.count)

        let writeStatuses = try opcua.write(
            nodeValues: [writableNodeValue],
            values: [DataValue(variant: Variant(value: Int32(1)))]
        ).wait()
        XCTAssertEqual(writeStatuses.count, 1)
    }

    func testSyncPublishingLifecycleAndExplicitPublish() throws {
        let opcua = try connectAnonymousSync()
        defer {
            try? opcua.disconnect(deleteSubscriptions: true).wait()
        }

        let subscriptionId = try opcua.createSubscription(
            subscription: makeSubscription(),
            startPublishing: false
        ).wait()

        let monitoredItems = try opcua.createMonitoredItems(
            subscriptionId: subscriptionId,
            itemsToCreate: makeMonitoredItems()
        ).wait()
        XCTAssertEqual(monitoredItems.count, monitoredNodeValues.count)
        XCTAssertTrue(monitoredItems.allSatisfy { $0.statusCode == .UA_STATUSCODE_GOOD })

        try opcua.publish().wait()
        try opcua.startPublishing(milliseconds: 300).wait()
        opcua.startPublishing()
        try opcua.stopPublishing().wait()

        let deleted = try opcua.deleteSubscriptions(subscriptionIds: [subscriptionId]).wait()
        XCTAssertEqual(deleted, [.UA_STATUSCODE_GOOD])
    }

    func testConnectionAsync() async throws {
        let opcua = try await connectSecureAsync(messageSecurityMode: .signAndEncrypt)
        do {
            let explicitBrowse = try await opcua.browse(
                nodes: [BrowseDescription(nodeValue: rootNodeValue)]
            )
            XCTAssertFalse(explicitBrowse.isEmpty)

            let readValues = monitoredNodeValues.map { ReadValue(nodeValue: $0) }
            let reads = try await opcua.read(nodes: readValues)
            XCTAssertEqual(reads.count, monitoredNodeValues.count)

            let statuses = try await opcua.write(
                nodes: [
                    WriteValue(
                        nodeValue: writableNodeValue,
                        value: DataValue(variant: Variant(value: Int32(1)))
                    )
                ]
            )
            XCTAssertEqual(statuses.count, 1)
        } catch {
            await disconnectAsync(opcua, deleteSubscriptions: true)
            throw error
        }

        await disconnectAsync(opcua, deleteSubscriptions: true)
    }

    func testAsyncNodeValueOverloadsAndPublishingLifecycle() async throws {
        let opcua = try await connectAnonymousAsync()
        do {
            let browseResults = try await opcua.browse(nodeValues: [rootNodeValue])
            XCTAssertEqual(browseResults.count, 1)
            XCTAssertFalse(browseResults[0].references.isEmpty)

            let reads = try await opcua.read(nodeValues: monitoredNodeValues)
            XCTAssertEqual(reads.count, monitoredNodeValues.count)

            let subscriptionId = try await opcua.createSubscription(
                subscription: makeSubscription(),
                startPublishing: false
            )
            let monitoredItems = try await opcua.createMonitoredItems(
                subscriptionId: subscriptionId,
                itemsToCreate: makeMonitoredItems()
            )
            XCTAssertEqual(monitoredItems.count, monitoredNodeValues.count)

            try await opcua.publish()
            try await opcua.startPublishing(milliseconds: 300)
            opcua.startPublishing()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await opcua.stopPublishing()

            let writeStatuses = try await opcua.write(
                nodeValues: [writableNodeValue],
                values: [DataValue(variant: Variant(value: Int32(0)))]
            )
            XCTAssertEqual(writeStatuses.count, 1)

            let deleted = try await opcua.deleteSubscriptions(subscriptionIds: [subscriptionId])
            XCTAssertEqual(deleted, [.UA_STATUSCODE_GOOD])
        } catch {
            await disconnectAsync(opcua, deleteSubscriptions: true)
            throw error
        }

        await disconnectAsync(opcua, deleteSubscriptions: true)
    }

    func testDataChangesStreamReceivesServerNotifications() async throws {
        let opcua = try await connectAnonymousAsync()
        do {
            let stream = opcua.dataChanges()
            let subscriptionId = try await opcua.createSubscription(
                subscription: makeSubscription(startPublishing: true),
                startPublishing: true
            )
            _ = try await opcua.createMonitoredItems(
                subscriptionId: subscriptionId,
                itemsToCreate: makeMonitoredItems()
            )

            let changes = try await nextDataChanges(from: stream)
            XCTAssertFalse(changes.isEmpty)
            XCTAssertTrue(changes.contains(where: { !$0.dataChangeNotification.monitoredItems.isEmpty }))

            let deleted = try await opcua.deleteSubscriptions(subscriptionIds: [subscriptionId])
            XCTAssertEqual(deleted, [.UA_STATUSCODE_GOOD])
        } catch {
            await disconnectAsync(opcua, deleteSubscriptions: true)
            throw error
        }

        await disconnectAsync(opcua, deleteSubscriptions: true)
    }

    func testConnectionWithSing() async throws {
        let opcua = try await connectSecureAsync(messageSecurityMode: .sign)
        do {
            let nodes = try await opcua.browse(nodeValues: [rootNodeValue])
            XCTAssertEqual(nodes.count, 1)
            XCTAssertFalse(nodes[0].references.isEmpty)
        } catch {
            await disconnectAsync(opcua, deleteSubscriptions: false)
            throw error
        }

        await disconnectAsync(opcua, deleteSubscriptions: false)
    }

    func testConnectionWithUsernamePassword() async throws {
        let opcua = try await connectUsernamePasswordAsync()
        do {
            let nodes = try await opcua.browse(nodeValues: [rootNodeValue])
            XCTAssertEqual(nodes.count, 1)
            XCTAssertFalse(nodes[0].references.isEmpty)
        } catch {
            await disconnectAsync(opcua, deleteSubscriptions: false)
            throw error
        }

        await disconnectAsync(opcua, deleteSubscriptions: false)
    }

    static let allTests = [
        ("testConnection", testConnection),
        ("testSyncPublishingLifecycleAndExplicitPublish", testSyncPublishingLifecycleAndExplicitPublish),
        ("testConnectionAsync", testConnectionAsync),
        ("testAsyncNodeValueOverloadsAndPublishingLifecycle", testAsyncNodeValueOverloadsAndPublishingLifecycle),
        ("testDataChangesStreamReceivesServerNotifications", testDataChangesStreamReceivesServerNotifications),
        ("testConnectionWithSing", testConnectionWithSing),
        ("testConnectionWithUsernamePassword", testConnectionWithUsernamePassword)
    ]
}
