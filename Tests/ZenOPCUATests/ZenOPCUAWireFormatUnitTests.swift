import Foundation
import XCTest
@testable import ZenOPCUA

/// Byte-level tests for the Variant/DataValue wire format and PublishRequest
/// subscription acknowledgements, matching the OPC UA binary encoding that
/// DataValue.parse expects (length prefix for strings/arrays).
final class ZenOPCUAWireFormatUnitTests: XCTestCase {

    // MARK: - Variant String wire format

    func testVariantStringWireBytesIncludeLengthPrefix() {
        let variant = Variant(value: "opcua")

        XCTAssertEqual(variant.type, DataType.string.rawValue)
        XCTAssertEqual(variant.bytes, UInt32(5).bytes + Array("opcua".utf8))
    }

    func testVariantStringValueGetterIsSymmetricWithLengthPrefix() {
        let variant = Variant(value: "opcua")

        XCTAssertEqual(variant.value as? String, "opcua")
    }

    func testDataValueEncodesVariantStringWithLengthPrefix() {
        let dataValue = DataValue(variant: Variant(value: "opcua"))

        XCTAssertEqual(dataValue.encodingMask, 0x01)
        XCTAssertEqual(
            dataValue.bytes,
            [0x01, DataType.string.rawValue] + UInt32(5).bytes + Array("opcua".utf8)
        )
    }

    func testDataValueParsesVariantStringWireBytes() {
        let bytes: [UInt8] = [0x01, DataType.string.rawValue]
            + UInt32(5).bytes + Array("opcua".utf8)
        var index = 0

        let parsed = DataValue(bytes: bytes, index: &index)

        XCTAssertEqual(parsed.variant.type, DataType.string.rawValue)
        XCTAssertEqual(parsed.variant.value as? String, "opcua")
        XCTAssertEqual(index, bytes.count)
    }

    func testVariantEmptyStringWireBytesUseNullLength() {
        let variant = Variant(value: "")

        // Wire format for an empty String is an explicit 0 length prefix.
        XCTAssertEqual(variant.bytes, UInt32(0).bytes)
        XCTAssertEqual(variant.value as? String, "")
    }

    // MARK: - Variant [Double] wire format

    func testVariantArrayOfDoubleWireBytesIncludeArrayLengthAndElements() {
        let variant = Variant(value: [1.5, 2.5])

        XCTAssertEqual(variant.type, DataType.arrayOfDouble.rawValue)
        XCTAssertEqual(variant.type, 139)
        XCTAssertEqual(
            variant.bytes,
            UInt32(2).bytes + 1.5.bytes + 2.5.bytes
        )
    }

    func testVariantArrayOfDoubleValueGetterIsSymmetric() {
        let variant = Variant(value: [1.5, 2.5])

        XCTAssertEqual(variant.value as? [Double], [1.5, 2.5])
    }

    func testDataValueEncodesVariantArrayOfDoubleWireBytes() {
        let dataValue = DataValue(variant: Variant(value: [1.5]))

        XCTAssertEqual(
            dataValue.bytes,
            [0x01, DataType.arrayOfDouble.rawValue]
                + UInt32(1).bytes
                + 1.5.bytes
        )
    }

    func testDataValueParsesVariantArrayOfDoubleWireBytes() {
        let bytes: [UInt8] = [0x01, DataType.arrayOfDouble.rawValue]
            + UInt32(2).bytes + 1.5.bytes + 2.5.bytes
        var index = 0

        let parsed = DataValue(bytes: bytes, index: &index)

        XCTAssertEqual(parsed.variant.type, DataType.arrayOfDouble.rawValue)
        XCTAssertEqual(parsed.variant.value as? [Double], [1.5, 2.5])
        XCTAssertEqual(index, bytes.count)
    }

    func testVariantEmptyArrayOfDoubleRoundTrips() {
        let variant = Variant(value: [Double]())

        XCTAssertEqual(variant.value as? [Double], [])
    }

    // MARK: - DataValue round-trip with known timestamps

    func testDataValueStringRoundTripWithStatusAndKnownTimestamps() {
        // 116_444_736_000_000_000 ticks == 1970-01-01T00:00:00Z (POSIX epoch).
        let sourceTicks = Int64(116_444_736_000_000_000)
        let serverTicks = Int64(116_444_736_100_000_000) // +10s
        let bytes: [UInt8] = [
            0x0F,
            DataType.string.rawValue
        ] + UInt32(5).bytes + Array("opcua".utf8)
            + StatusCodes.UA_STATUSCODE_BADUNEXPECTEDERROR.rawValue.bytes
            + sourceTicks.bytes
            + serverTicks.bytes
        var index = 0

        let parsed = DataValue(bytes: bytes, index: &index)

        XCTAssertEqual(parsed.variant.value as? String, "opcua")
        XCTAssertEqual(parsed.statusCode, .UA_STATUSCODE_BADUNEXPECTEDERROR)
        XCTAssertEqual(parsed.sourceTimestamp.timeIntervalSince1970, 0, accuracy: 0.001)
        XCTAssertEqual(parsed.serverTimestamp.timeIntervalSince1970, 10, accuracy: 0.001)
        XCTAssertEqual(index, bytes.count)
    }

    func testDataValueArrayOfDoubleRoundTripWithStatusAndTimestamps() {
        let sourceTicks = Int64(116_444_736_000_000_000)
        let serverTicks = Int64(116_444_736_000_000_000)
        let bytes: [UInt8] = [
            0x0F,
            DataType.arrayOfDouble.rawValue
        ] + UInt32(3).bytes + 1.5.bytes + (-2.5).bytes + Double(0).bytes
            + StatusCodes.UA_STATUSCODE_GOOD.rawValue.bytes
            + sourceTicks.bytes
            + serverTicks.bytes
        var index = 0

        let parsed = DataValue(bytes: bytes, index: &index)

        XCTAssertEqual(parsed.variant.value as? [Double], [1.5, -2.5, 0])
        XCTAssertEqual(parsed.statusCode, .UA_STATUSCODE_GOOD)
        XCTAssertEqual(parsed.sourceTimestamp.timeIntervalSince1970, 0, accuracy: 0.001)
        XCTAssertEqual(parsed.serverTimestamp.timeIntervalSince1970, 0, accuracy: 0.001)
        XCTAssertEqual(index, bytes.count)
    }

    // MARK: - PublishRequest subscription acknowledgements

    func testSubscriptionAcknowledgementWireBytesAreIdPlusSequenceNumber() {
        let ack = SubscriptionAcknowledgement(subscriptionId: 7, sequenceNumber: 42)

        XCTAssertEqual(ack.bytes, UInt32(7).bytes + UInt32(42).bytes)
    }

    func testPublishRequestEncodesAcknowledgementPairs() {
        let request = PublishRequest(
            secureChannelId: 1,
            tokenId: 2,
            requestId: 3,
            requestHandle: 3,
            authenticationTokenValue: NodeValue.base(identifier: 4),
            subscriptionAcknowledgements: [
                SubscriptionAcknowledgement(subscriptionId: 7, sequenceNumber: 42),
                SubscriptionAcknowledgement(subscriptionId: 8, sequenceNumber: 43)
            ]
        )

        let expectedSuffix = UInt32(2).bytes
            + UInt32(7).bytes + UInt32(42).bytes
            + UInt32(8).bytes + UInt32(43).bytes

        XCTAssertEqual(Array(request.bytes.suffix(expectedSuffix.count)), expectedSuffix)
    }

    func testPublishRequestWithNoAcknowledgementsEncodesEmptyArray() {
        let request = PublishRequest(
            secureChannelId: 1,
            tokenId: 2,
            requestId: 3,
            requestHandle: 3,
            authenticationTokenValue: NodeValue.base(identifier: 4)
        )

        XCTAssertEqual(Array(request.bytes.suffix(4)), UInt32(0).bytes)
    }

    func testSubscriptionAckRuntimeTracksLastSequenceNumberPerSubscription() {
        let runtime = SubscriptionAckRuntime()

        runtime.record(41, for: 7)
        runtime.record(42, for: 7)
        runtime.record(100, for: 8)

        let lastFor7 = runtime.currentSequenceNumber(for: 7)
        XCTAssertEqual(lastFor7, 42)

        let all = runtime.acknowledgements(forSubscriptionIds: [])
        XCTAssertEqual(all, [
            SubscriptionAcknowledgement(subscriptionId: 7, sequenceNumber: 42),
            SubscriptionAcknowledgement(subscriptionId: 8, sequenceNumber: 100)
        ])

        let filtered = runtime.acknowledgements(forSubscriptionIds: [8])
        XCTAssertEqual(filtered, [SubscriptionAcknowledgement(subscriptionId: 8, sequenceNumber: 100)])

        let unknown = runtime.acknowledgements(forSubscriptionIds: [999])
        XCTAssertEqual(unknown, [])
    }

    static let allTests = [
        ("testVariantStringWireBytesIncludeLengthPrefix", testVariantStringWireBytesIncludeLengthPrefix),
        ("testVariantStringValueGetterIsSymmetricWithLengthPrefix", testVariantStringValueGetterIsSymmetricWithLengthPrefix),
        ("testDataValueEncodesVariantStringWithLengthPrefix", testDataValueEncodesVariantStringWithLengthPrefix),
        ("testDataValueParsesVariantStringWireBytes", testDataValueParsesVariantStringWireBytes),
        ("testVariantEmptyStringWireBytesUseNullLength", testVariantEmptyStringWireBytesUseNullLength),
        ("testVariantArrayOfDoubleWireBytesIncludeArrayLengthAndElements", testVariantArrayOfDoubleWireBytesIncludeArrayLengthAndElements),
        ("testVariantArrayOfDoubleValueGetterIsSymmetric", testVariantArrayOfDoubleValueGetterIsSymmetric),
        ("testDataValueEncodesVariantArrayOfDoubleWireBytes", testDataValueEncodesVariantArrayOfDoubleWireBytes),
        ("testDataValueParsesVariantArrayOfDoubleWireBytes", testDataValueParsesVariantArrayOfDoubleWireBytes),
        ("testVariantEmptyArrayOfDoubleRoundTrips", testVariantEmptyArrayOfDoubleRoundTrips),
        ("testDataValueStringRoundTripWithStatusAndKnownTimestamps", testDataValueStringRoundTripWithStatusAndKnownTimestamps),
        ("testDataValueArrayOfDoubleRoundTripWithStatusAndTimestamps", testDataValueArrayOfDoubleRoundTripWithStatusAndTimestamps),
        ("testSubscriptionAcknowledgementWireBytesAreIdPlusSequenceNumber", testSubscriptionAcknowledgementWireBytesAreIdPlusSequenceNumber),
        ("testPublishRequestEncodesAcknowledgementPairs", testPublishRequestEncodesAcknowledgementPairs),
        ("testPublishRequestWithNoAcknowledgementsEncodesEmptyArray", testPublishRequestWithNoAcknowledgementsEncodesEmptyArray),
        ("testSubscriptionAckRuntimeTracksLastSequenceNumberPerSubscription", testSubscriptionAckRuntimeTracksLastSequenceNumberPerSubscription)
    ]
}
