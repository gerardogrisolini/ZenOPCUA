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
        let calendar = Calendar(identifier: .gregorian)
        let epoch = calendar.date(from: DateComponents(year: 1601, month: 1, day: 1))!

        XCTAssertEqual(epoch.ticks, 0)
        XCTAssertEqual(epoch.bytes, Int64(0).bytes)
    }

    func testInt64DateUtcUsesExpectedOffset() {
        let date = Int64(0).dateUtc
        let calendar = Calendar(identifier: .gregorian)
        let epoch = calendar.date(from: DateComponents(year: 1601, month: 1, day: 1))!
        let expected = Date(timeInterval: 3000, since: epoch)

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
