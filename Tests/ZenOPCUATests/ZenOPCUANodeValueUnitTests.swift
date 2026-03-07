import XCTest
@testable import ZenOPCUA

final class ZenOPCUANodeValueUnitTests: XCTestCase {
    func testMethodInitializerCreatesNumericNodeValue() {
        let node = NodeValue(method: .browseRequest)

        XCTAssertEqual(node.bytes, [Nodes.numeric.rawValue, 0] + Methods.browseRequest.rawValue.bytes)
    }

    func testNodeValueBytesForAllCases() {
        let values: [NodeValue] = [
            .base(identifier: 1),
            .compact(encoding: .stringExt, identifier: 2),
            .numeric(nameSpace: 3, identifier: 4),
            .long(nameSpace: 5, identifier: 6),
            .string(nameSpace: 7, identifier: "abc"),
            .guid(nameSpace: 8, identifier: Array(0..<16)),
            .byteString(nameSpace: 9, identifier: [1, 2, 3]),
            .baseExt(identifier: 10, serverIndex: 11),
            .numericExt(nameSpace: 12, identifier: 13, serverIndex: 14),
            .stringExt(nameSpace: 15, identifier: "opcua", serverIndex: 16)
        ]

        XCTAssertEqual(values[0].bytes, [0x00, 1])
        XCTAssertEqual(values[1].bytes, [Nodes.stringExt.rawValue, 2])
        XCTAssertEqual(values[2].bytes, [0x01, 3] + UInt16(4).bytes)
        XCTAssertEqual(values[3].bytes, [0x02] + UInt16(5).bytes + UInt32(6).bytes)
        XCTAssertEqual(values[4].bytes, [0x03] + UInt16(7).bytes + "abc".bytes)
        XCTAssertEqual(values[5].bytes, [0x04] + UInt16(8).bytes + Array(0..<16))
        XCTAssertEqual(values[6].bytes, [0x05] + UInt16(9).bytes + UInt32(3).bytes + [1, 2, 3])
        XCTAssertEqual(values[7].bytes, [0x40, 10] + UInt32(11).bytes)
        XCTAssertEqual(values[8].bytes, [0x41, 12] + UInt16(13).bytes + UInt32(14).bytes)
        XCTAssertEqual(values[9].bytes, [0x43] + UInt16(15).bytes + "opcua".bytes + UInt32(16).bytes)
    }

    func testNodeValueParseRoundTripsAllSupportedEncodings() {
        let values: [NodeValue] = [
            .base(identifier: 1),
            .numeric(nameSpace: 3, identifier: 4),
            .long(nameSpace: 5, identifier: 6),
            .string(nameSpace: 7, identifier: "abc"),
            .guid(nameSpace: 8, identifier: Array(0..<16)),
            .byteString(nameSpace: 9, identifier: [1, 2, 3]),
            .baseExt(identifier: 10, serverIndex: 11),
            .numericExt(nameSpace: 12, identifier: 13, serverIndex: 14),
            .stringExt(nameSpace: 15, identifier: "opcua", serverIndex: 16)
        ]

        for original in values {
            var index = 0
            let parsed = NodeValue.parse(index: &index, bytes: original.bytes)

            XCTAssertEqual(parsed.bytes, original.bytes)
            XCTAssertEqual(index, original.bytes.count)
        }
    }

    func testNodeValueParseFallsBackOnInvalidEncoding() {
        var index = 0
        let parsed = NodeValue.parse(index: &index, bytes: [0xFF, 0x01])

        XCTAssertEqual(parsed.bytes, NodeValue.base(identifier: 0).bytes)
        XCTAssertEqual(index, 1)
    }

    func testNodeValueParseFallsBackOnTruncatedPayload() {
        var index = 0
        let parsed = NodeValue.parse(index: &index, bytes: [Nodes.numeric.rawValue, 0x01])

        XCTAssertEqual(parsed.bytes, NodeValue.base(identifier: 0).bytes)
        XCTAssertEqual(index, 1)
    }

    func testNodeValueInterpolationIncludesCaseName() {
        let rendered = "\(NodeValue.numeric(nameSpace: 2, identifier: 42))"

        XCTAssertTrue(rendered.contains("NodeValue.numeric"))
        XCTAssertTrue(rendered.contains("nameSpace = 2"))
        XCTAssertTrue(rendered.contains("identifier = 42"))
    }

    static let allTests = [
        ("testMethodInitializerCreatesNumericNodeValue", testMethodInitializerCreatesNumericNodeValue),
        ("testNodeValueBytesForAllCases", testNodeValueBytesForAllCases),
        ("testNodeValueParseRoundTripsAllSupportedEncodings", testNodeValueParseRoundTripsAllSupportedEncodings),
        ("testNodeValueParseFallsBackOnInvalidEncoding", testNodeValueParseFallsBackOnInvalidEncoding),
        ("testNodeValueParseFallsBackOnTruncatedPayload", testNodeValueParseFallsBackOnTruncatedPayload),
        ("testNodeValueInterpolationIncludesCaseName", testNodeValueInterpolationIncludesCaseName)
    ]
}
