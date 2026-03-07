import XCTest
import NIO
@testable import ZenOPCUA

final class ZenOPCUADataValueAndActorsUnitTests: XCTestCase {
    func testVariantTypedInitializersExposeExpectedValues() {
        XCTAssertEqual(Variant(value: true).value as? Bool, true)
        XCTAssertEqual(Variant(value: UInt16(7)).value as? UInt16, 7)
        XCTAssertEqual(Variant(value: Int16(-7)).value as? Int16, -7)
        XCTAssertEqual(Variant(value: UInt32(8)).value as? UInt32, 8)
        XCTAssertEqual(Variant(value: Int32(-8)).value as? Int32, -8)
        XCTAssertEqual(Variant(value: Float(1.5)).value as? Float, 1.5)
        XCTAssertEqual(Variant(value: Double(2.5)).value as? Double, 2.5)
        XCTAssertEqual(Variant(value: "opcua").value as? String, "opcua")
    }

    func testVariantArrayOfDoubleValueRoundTrips() {
        let variant = Variant(value: [1.5, 2.5])
        let value = variant.value as? [Double]

        XCTAssertEqual(variant.type, DataType.arrayOfDouble.rawValue)
        XCTAssertEqual(value ?? [], [1.5, 2.5])
    }

    func testDataValueVariantInitializerSetsEncodingMaskAndBytes() {
        let dataValue = DataValue(variant: Variant(value: Int32(42)))

        XCTAssertEqual(dataValue.encodingMask, 0x01)
        XCTAssertEqual(dataValue.bytes, [0x01, DataType.int32.rawValue] + Int32(42).bytes)
    }

    func testDataValueParsingReadsStatusAndTimestamps() {
        let source = Int64(10_000_000)
        let server = Int64(20_000_000)
        let bytes: [UInt8] = [
            0x0F,
            DataType.int32.rawValue
        ] + Int32(42).bytes
            + StatusCodes.UA_STATUSCODE_BADUNEXPECTEDERROR.rawValue.bytes
            + source.bytes
            + server.bytes
        var index = 0

        let parsed = DataValue(bytes: bytes, index: &index)

        XCTAssertEqual(parsed.encodingMask, 0x0F)
        XCTAssertEqual(parsed.variant.type, DataType.int32.rawValue)
        XCTAssertEqual(parsed.variant.value as? Int32, 42)
        XCTAssertEqual(parsed.statusCode, .UA_STATUSCODE_BADUNEXPECTEDERROR)
        XCTAssertEqual(index, bytes.count)
    }

    func testClientCallbackRuntimeStoresCallbacks() {
        let runtime = ClientCallbackRuntime()
        let onDataChanged: OPCUADataChanged = { _ in }
        let onHandlerActivated: OPCUAHandlerChange = {}
        let onHandlerRemoved: OPCUAHandlerChange = {}
        let onErrorCaught: OPCUAErrorCaught = { _ in }

        runtime.updateOnDataChanged(onDataChanged)
        runtime.updateOnHandlerActivated(onHandlerActivated)
        runtime.updateOnHandlerRemoved(onHandlerRemoved)
        runtime.updateOnErrorCaught(onErrorCaught)

        XCTAssertNotNil(runtime.currentOnDataChanged)
        XCTAssertNotNil(runtime.currentOnHandlerActivated)
        XCTAssertNotNil(runtime.currentOnHandlerRemoved)
        XCTAssertNotNil(runtime.currentOnErrorCaught)
    }

    func testConnectionCoordinatorSnapshotProviderStoresSnapshot() {
        let initial = ConnectionCoordinator.buildInitialSnapshot()
        let provider = ConnectionCoordinatorSnapshotProvider(snapshot: initial)
        let updated = ConnectionCoordinatorSnapshot(
            currentChannel: nil,
            currentEventLoop: nil,
            shouldAttemptReconnect: false,
            currentPhase: .disconnecting,
            canBeginConnect: false,
            canBeginDisconnect: false,
            canStartTransport: false,
            lifecycleReconnectEnabled: true,
            lifecycleIsAcknowledging: true,
            lifecycleIsUpgradingToSecure: true,
            shouldUseUnsignedBootstrapSecurityOnCurrentTransport: false,
            hasRetriedOpnThumbprintCompatibility: true
        )

        provider.store(updated)

        XCTAssertEqual(provider.currentSnapshot.currentPhase, .disconnecting)
        XCTAssertTrue(provider.currentSnapshot.lifecycleReconnectEnabled)
        XCTAssertTrue(provider.currentSnapshot.lifecycleIsAcknowledging)
        XCTAssertTrue(provider.currentSnapshot.lifecycleIsUpgradingToSecure)
        XCTAssertTrue(provider.currentSnapshot.hasRetriedOpnThumbprintCompatibility)
    }

    func testConnectionCoordinatorLifecycleTransitions() async {
        let provider = ConnectionCoordinatorSnapshotProvider(snapshot: ConnectionCoordinator.buildInitialSnapshot())
        let coordinator = ConnectionCoordinator(snapshotProvider: provider)

        await coordinator.prepareForConnect()
        XCTAssertEqual(provider.currentSnapshot.currentPhase, .connecting)
        XCTAssertTrue(provider.currentSnapshot.lifecycleIsAcknowledging)
        XCTAssertTrue(provider.currentSnapshot.canStartTransport)

        await coordinator.setReconnectEnabled(true)
        XCTAssertTrue(provider.currentSnapshot.lifecycleReconnectEnabled)

        await coordinator.completeAcknowledge()
        XCTAssertFalse(provider.currentSnapshot.lifecycleIsAcknowledging)

        let enteredBackoff = await coordinator.enterReconnectBackoff()
        XCTAssertTrue(enteredBackoff)
        XCTAssertEqual(provider.currentSnapshot.currentPhase, .waitingToReconnect)
        let resumedBackoff = await coordinator.resumeReconnectFromBackoff()
        XCTAssertTrue(resumedBackoff)
        XCTAssertEqual(provider.currentSnapshot.currentPhase, .reconnecting)

        await coordinator.markOpnThumbprintRetryDone()
        XCTAssertTrue(provider.currentSnapshot.hasRetriedOpnThumbprintCompatibility)
        await coordinator.resetOpnThumbprintRetry()
        XCTAssertFalse(provider.currentSnapshot.hasRetriedOpnThumbprintCompatibility)

        await coordinator.setUpgradingToSecure(true)
        XCTAssertTrue(provider.currentSnapshot.lifecycleIsUpgradingToSecure)
        await coordinator.markSecuredTransportActive()
        XCTAssertFalse(provider.currentSnapshot.shouldUseUnsignedBootstrapSecurityOnCurrentTransport)
        await coordinator.resetUnsignedBootstrapSecurity(hasRemoteCertificate: false)
        XCTAssertTrue(provider.currentSnapshot.shouldUseUnsignedBootstrapSecurityOnCurrentTransport)

        await coordinator.prepareForDisconnect()
        XCTAssertEqual(provider.currentSnapshot.currentPhase, .disconnecting)
        let enteredBackoffWhileDisconnecting = await coordinator.enterReconnectBackoff()
        XCTAssertFalse(enteredBackoffWhileDisconnecting)

        await coordinator.markStartFailed()
        XCTAssertEqual(provider.currentSnapshot.currentPhase, .disconnecting)
        XCTAssertFalse(provider.currentSnapshot.lifecycleIsAcknowledging)

        await coordinator.disableReconnect()
        XCTAssertFalse(provider.currentSnapshot.lifecycleReconnectEnabled)

        await coordinator.clearConnection()
        XCTAssertEqual(provider.currentSnapshot.currentPhase, .idle)
        XCTAssertTrue(provider.currentSnapshot.canBeginConnect)
    }

    func testPublishingRuntimeTracksMilliseconds() async {
        let runtime = PublishingRuntime()

        let initialMilliseconds = await runtime.currentMilliseconds()
        XCTAssertEqual(initialMilliseconds, 0)
        await runtime.setMilliseconds(250)
        let updatedMilliseconds = await runtime.currentMilliseconds()
        XCTAssertEqual(updatedMilliseconds, 250)
        let publisher = await runtime.takePublisher()
        XCTAssertNil(publisher)
    }

    static let allTests = [
        ("testVariantTypedInitializersExposeExpectedValues", testVariantTypedInitializersExposeExpectedValues),
        ("testVariantArrayOfDoubleValueRoundTrips", testVariantArrayOfDoubleValueRoundTrips),
        ("testDataValueVariantInitializerSetsEncodingMaskAndBytes", testDataValueVariantInitializerSetsEncodingMaskAndBytes),
        ("testDataValueParsingReadsStatusAndTimestamps", testDataValueParsingReadsStatusAndTimestamps),
        ("testClientCallbackRuntimeStoresCallbacks", testClientCallbackRuntimeStoresCallbacks),
        ("testConnectionCoordinatorSnapshotProviderStoresSnapshot", testConnectionCoordinatorSnapshotProviderStoresSnapshot),
        ("testConnectionCoordinatorLifecycleTransitions", testConnectionCoordinatorLifecycleTransitions),
        ("testPublishingRuntimeTracksMilliseconds", testPublishingRuntimeTracksMilliseconds)
    ]
}
