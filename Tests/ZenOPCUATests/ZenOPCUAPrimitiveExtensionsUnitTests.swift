import Foundation
import XCTest
@testable import ZenOPCUA

final class ZenOPCUAPrimitiveExtensionsUnitTests: XCTestCase {
    func testBoolByteConversionsRoundTrip() {
        XCTAssertTrue(Bool(byte: 0x01))
        XCTAssertFalse(Bool(byte: 0x00))
        XCTAssertEqual(true.bytes, [0x01])
        XCTAssertEqual(false.bytes, [0x00])
    }

    func testFixedWidthIntegerByteRoundTrip() {
        let uint16 = UInt16(0x1234)
        let uint32 = UInt32(0x12345678)

        XCTAssertEqual(UInt16(bytes: uint16.bytes), uint16)
        XCTAssertEqual(UInt32(bytes: uint32.bytes), uint32)
    }

    func testStringSecurityPolicyParsing() {
        XCTAssertEqual(
            "http://opcfoundation.org/UA/SecurityPolicy#Basic256Sha256".securityPolicy,
            .basic256Sha256
        )
        XCTAssertEqual("not-a-policy".securityPolicy, .none)
    }

    func testDateTimeEpochConversion() {
        // POSIX epoch (1970-01-01T00:00:00Z) in OPC UA ticks: 11_644_473_600s * 10_000_000.
        let posixEpoch = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(posixEpoch.ticks, 116_444_736_000_000_000)

        // Known instant: 2024-01-01T00:00:00Z = 1_704_067_200 POSIX seconds.
        let known = Date(timeIntervalSince1970: 1_704_067_200)
        XCTAssertEqual(known.ticks, (1_704_067_200 + 116_444_736_00) * 10_000_000)
    }

    func testDateTimeRoundTrip() {
        let original = Date(timeIntervalSince1970: 1_704_067_200.123)
        let decoded = original.ticks.date
        // Ticks have 100ns resolution: allow sub-microsecond drift.
        XCTAssertEqual(decoded.timeIntervalSince1970, original.timeIntervalSince1970, accuracy: 0.000_001)
        XCTAssertEqual(original.ticks.dateUtc.timeIntervalSince1970, original.timeIntervalSince1970, accuracy: 0.000_001)
    }

    func testDateTimeDecodingOfKnownTicks() {
        // 116_444_736_000_000_000 ticks == 1970-01-01T00:00:00Z.
        XCTAssertEqual(Int64(116_444_736_000_000_000).date.timeIntervalSince1970, 0, accuracy: 0.000_001)
        XCTAssertEqual(Int64(116_444_736_000_000_000).dateUtc.timeIntervalSince1970, 0, accuracy: 0.000_001)
    }

    func testStringOptionalAndEmptyEncoding() {
        XCTAssertEqual("abc".bytes, UInt32(3).bytes + [97, 98, 99])
        XCTAssertEqual("".bytes, UInt32.max.bytes)

        let value: String? = "opcua"
        let nilValue: String? = nil

        XCTAssertEqual(value.bytes, "opcua".bytes)
        XCTAssertEqual(nilValue.bytes, UInt32.max.bytes)
    }

    func testArrayBytesConcatenatesEncodableValues() {
        XCTAssertEqual([UInt16(1), UInt16(2)].bytes, UInt16(1).bytes + UInt16(2).bytes)
    }

    func testDoubleAndFloatRoundTrip() {
        let double = Double.pi
        let float: Float = 123.5

        XCTAssertEqual(Double(bytes: double.bytes), double)
        XCTAssertEqual(Float(bytes: float.bytes), float)
    }

    func testDateTicksAndBytesForEpoch() {
        // OPC UA epoch: 1601-01-01T00:00:00Z == 11_644_473_600 seconds before
        // the POSIX epoch. Pure UTC arithmetic, locale-independent.
        let opcuaEpoch = Date(timeIntervalSince1970: -11_644_473_600)

        XCTAssertEqual(opcuaEpoch.ticks, 0)
        XCTAssertEqual(opcuaEpoch.bytes, Int64(0).bytes)
    }

    func testInt64DateUtcUsesExpectedOffset() {
        // 0 ticks decodes to the OPC UA epoch itself (no spurious +3000s and
        // no local timezone offset).
        let date = Int64(0).dateUtc
        let expected = Date(timeIntervalSince1970: -11_644_473_600)

        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)
    }

    func testMessageHeaderInitializers() {
        let header = MessageHeader(
            secureChannelId: 1,
            tokenId: 2,
            sequenceNumber: 3,
            requestId: 4
        )
        let bytes = UInt32(1).bytes + UInt32(2).bytes + UInt32(3).bytes + UInt32(4).bytes
        let decoded = MessageHeader(bytes: bytes)
        let invalid = MessageHeader(bytes: [1, 2, 3])

        XCTAssertEqual(header.secureChannelId, 1)
        XCTAssertEqual(header.tokenId, 2)
        XCTAssertEqual(header.sequenceNumber, 3)
        XCTAssertEqual(header.requestId, 4)
        XCTAssertEqual(decoded.secureChannelId, 1)
        XCTAssertEqual(decoded.tokenId, 2)
        XCTAssertEqual(decoded.sequenceNumber, 3)
        XCTAssertEqual(decoded.requestId, 4)
        XCTAssertEqual(invalid.secureChannelId, 0)
        XCTAssertEqual(invalid.tokenId, 0)
        XCTAssertEqual(invalid.sequenceNumber, 0)
        XCTAssertEqual(invalid.requestId, 0)
    }

    func testNSLockWithLockExecutesBody() {
        let lock = NSLock()
        var value = 0

        let result = lock.withLock {
            value += 1
            return value
        }

        XCTAssertEqual(result, 1)
        XCTAssertEqual(value, 1)
    }

    func testChunkedAndContiguousByteLoads() {
        let doubles = [1.5, 2.5]
        let bytes = doubles.flatMap(\.bytes)
        let chunks = bytes.chunked(into: 8)

        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].load() as Double, 1.5)
        XCTAssertEqual(chunks[1].load() as Double, 2.5)
    }

    static let allTests = [
        ("testBoolByteConversionsRoundTrip", testBoolByteConversionsRoundTrip),
        ("testFixedWidthIntegerByteRoundTrip", testFixedWidthIntegerByteRoundTrip),
        ("testStringSecurityPolicyParsing", testStringSecurityPolicyParsing),
        ("testStringOptionalAndEmptyEncoding", testStringOptionalAndEmptyEncoding),
        ("testArrayBytesConcatenatesEncodableValues", testArrayBytesConcatenatesEncodableValues),
        ("testDoubleAndFloatRoundTrip", testDoubleAndFloatRoundTrip),
        ("testDateTicksAndBytesForEpoch", testDateTicksAndBytesForEpoch),
        ("testInt64DateUtcUsesExpectedOffset", testInt64DateUtcUsesExpectedOffset),
        ("testMessageHeaderInitializers", testMessageHeaderInitializers),
        ("testNSLockWithLockExecutesBody", testNSLockWithLockExecutesBody),
        ("testChunkedAndContiguousByteLoads", testChunkedAndContiguousByteLoads)
    ]
}
