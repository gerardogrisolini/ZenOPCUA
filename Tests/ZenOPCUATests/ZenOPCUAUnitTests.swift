import XCTest
import NIO
@testable import ZenOPCUA

final class ZenOPCUAUnitTests: XCTestCase {
    private enum StreamTestError: Error {
        case timeout
    }

    var eventLoopGroup: MultiThreadedEventLoopGroup!

    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    }

    override func tearDown() {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    private func awaitFirstValue<T: Sendable>(
        from operation: @escaping @Sendable () async -> T?,
        timeoutNanoseconds: UInt64 = 2_000_000_000
    ) -> Task<T, Error> {
        Task {
            try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    guard let value = await operation() else {
                        throw StreamTestError.timeout
                    }
                    return value
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    throw StreamTestError.timeout
                }

                let firstCompleted = try await group.next()
                group.cancelAll()
                return try XCTUnwrap(firstCompleted)
            }
        }
    }

    private func emitDataChangesUntilTasksComplete(
        _ tasks: [Task<[DataChange], Error>],
        using opcua: ZenOPCUA,
        change: DataChange,
        attempts: Int = 10,
        pauseNanoseconds: UInt64 = 50_000_000
    ) async {
        for _ in 0..<attempts where tasks.contains(where: { !$0.isCancelled }) {
            opcua.notifyDataChangeObservers([change])
            await Task.yield()
            try? await Task.sleep(nanoseconds: pauseNanoseconds)
        }
    }

    private func emitErrorsUntilTasksComplete(
        _ tasks: [Task<OPCUAError, Error>],
        using opcua: ZenOPCUA,
        error: OPCUAError,
        attempts: Int = 10,
        pauseNanoseconds: UInt64 = 50_000_000
    ) async {
        for _ in 0..<attempts where tasks.contains(where: { !$0.isCancelled }) {
            opcua.notifyErrorObservers(error)
            await Task.yield()
            try? await Task.sleep(nanoseconds: pauseNanoseconds)
        }
    }

    func testDataChangesStreamSupportsMultipleSubscribers() async throws {
        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://localhost:4840"
        )
        let expectedChange = DataChange()

        let firstTask = awaitFirstValue {
            var iterator = opcua.dataChanges().makeAsyncIterator()
            return await iterator.next()
        }
        let secondTask = awaitFirstValue {
            var iterator = opcua.dataChanges().makeAsyncIterator()
            return await iterator.next()
        }

        await emitDataChangesUntilTasksComplete(
            [firstTask, secondTask],
            using: opcua,
            change: expectedChange
        )

        let first = try await firstTask.value
        let second = try await secondTask.value

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
    }

    func testErrorsStreamSupportsMultipleSubscribers() async throws {
        let opcua = ZenOPCUA(
            eventLoopGroup: eventLoopGroup,
            endpointUrl: "opc.tcp://localhost:4840"
        )
        let expectedError = OPCUAError.timeout

        let firstTask = awaitFirstValue {
            var iterator = opcua.errors().makeAsyncIterator()
            return await iterator.next() as? OPCUAError
        }
        let secondTask = awaitFirstValue {
            var iterator = opcua.errors().makeAsyncIterator()
            return await iterator.next() as? OPCUAError
        }

        await emitErrorsUntilTasksComplete(
            [firstTask, secondTask],
            using: opcua,
            error: expectedError
        )

        let first = try await firstTask.value
        let second = try await secondTask.value

        XCTAssertEqual(first, .timeout)
        XCTAssertEqual(second, .timeout)
    }

    static let allTests = [
        ("testDataChangesStreamSupportsMultipleSubscribers", testDataChangesStreamSupportsMultipleSubscribers),
        ("testErrorsStreamSupportsMultipleSubscribers", testErrorsStreamSupportsMultipleSubscribers)
    ]
}
