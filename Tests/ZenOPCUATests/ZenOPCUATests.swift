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
        let opcua = ZenOPCUA(host: "opcua.rocks", port: 4840, reconnect: false, eventLoopGroup: eventLoopGroup)
        opcua.onMessageReceived = { message in
            print(message)
        }
        opcua.onHandlerRemoved = {
            print("Handler removed")
        }
        opcua.onErrorCaught = { error in
            print(error)
        }
        
        do {
            try opcua.connect().wait()
            sleep(3)

            let item = try opcua.browse().wait()
            item.references.forEach { ref in
                print(ref.displayName.text)
                switch ref.nodeId.encodingMask {
                case .numeric:
                    print((ref.nodeId as! NodeIdNumeric).identifier)
                    print((ref.nodeId as! NodeIdNumeric).nameSpace)
                case .string:
                    print((ref.nodeId as! NodeIdString).identifier)
                default:
                    print((ref.nodeId as! NodeId).identifierNumeric)
                }
            }
            sleep(5)

//            let nodes = [ReadValueId(nodeId: NodeIdNumeric(nameSpace: 1, identifier: 62541))]
//            let value = try opcua.read(nodes: nodes).wait()
//            print(value)
//            sleep(3)
            
            try opcua.disconnect().wait()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEmpty() {
        let empty: [UInt8] = [0xff, 0xff, 0xff, 0xff]
        let number = UInt32(littleEndianBytes: empty)
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
        //0x4d, 0x53, 0x47, 0x46, 0x45, 0x02, 0x00, 0x00,
        0x35, 0x65, 0x00, 0x00, 0x1a, 0x5b, 0x01, 0x00,
        0x03, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
        0x01, 0x00, 0xd0, 0x01, 0x40, 0xa2, 0xbf, 0x57,
        0xe1, 0xe8, 0xd5, 0x01, 0x02, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
        0xff, 0x00, 0x00, 0x00, 0x04, 0x01, 0x00, 0xd9,
        0x63, 0xe7, 0x40, 0x5b, 0x3a, 0x81, 0x88, 0xdc,
        0xdd, 0xbd, 0xbb, 0x8d, 0x68, 0xb6, 0xcb, 0x04,
        0x01, 0x00, 0x0b, 0x98, 0xbf, 0x77, 0xd6, 0x39,
        0x18, 0xde, 0xb5, 0x1b, 0x21, 0x72, 0x68, 0x36,
        0xe3, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x80, 0x4f,
        0x32, 0x41, 0x20, 0x00, 0x00, 0x00, 0x0f, 0x22,
        0xe8, 0xf0, 0x88, 0x08, 0x21, 0x08, 0xd4, 0x2d,
        0x21, 0x46, 0xfd, 0xb7, 0x04, 0xac, 0xbe, 0x60,
        0xa1, 0x2d, 0x0c, 0x38, 0x9e, 0x66, 0x65, 0x89,
        0x76, 0xce, 0xca, 0xe3, 0x0a, 0xc1, 0xff, 0xff,
        0xff, 0xff, 0x01, 0x00, 0x00, 0x00, 0x1f, 0x00,
        0x00, 0x00, 0x6f, 0x70, 0x63, 0x2e, 0x74, 0x63,
        0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70, 0x63, 0x75,
        0x61, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x2e,
        0x63, 0x6f, 0x6d, 0x3a, 0x34, 0x38, 0x34, 0x38,
        0x34, 0x1c, 0x00, 0x00, 0x00, 0x75, 0x72, 0x6e,
        0x3a, 0x75, 0x6e, 0x63, 0x6f, 0x6e, 0x66, 0x69,
        0x67, 0x75, 0x72, 0x65, 0x64, 0x3a, 0x61, 0x70,
        0x70, 0x6c, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6f,
        0x6e, 0x14, 0x00, 0x00, 0x00, 0x68, 0x74, 0x74,
        0x70, 0x3a, 0x2f, 0x2f, 0x6f, 0x70, 0x65, 0x6e,
        0x36, 0x32, 0x35, 0x34, 0x31, 0x2e, 0x6f, 0x72,
        0x67, 0x03, 0x02, 0x00, 0x00, 0x00, 0x65, 0x6e,
        0x22, 0x00, 0x00, 0x00, 0x6f, 0x70, 0x65, 0x6e,
        0x36, 0x32, 0x35, 0x34, 0x31, 0x2d, 0x62, 0x61,
        0x73, 0x65, 0x64, 0x20, 0x4f, 0x50, 0x43, 0x20,
        0x55, 0x41, 0x20, 0x41, 0x70, 0x70, 0x6c, 0x69,
        0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x00, 0x00,
        0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x01, 0x00, 0x00, 0x00, 0x2f, 0x00,
        0x00, 0x00, 0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f,
        0x2f, 0x6f, 0x70, 0x63, 0x66, 0x6f, 0x75, 0x6e,
        0x64, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x2e, 0x6f,
        0x72, 0x67, 0x2f, 0x55, 0x41, 0x2f, 0x53, 0x65,
        0x63, 0x75, 0x72, 0x69, 0x74, 0x79, 0x50, 0x6f,
        0x6c, 0x69, 0x63, 0x79, 0x23, 0x4e, 0x6f, 0x6e,
        0x65, 0x02, 0x00, 0x00, 0x00, 0x1a, 0x00, 0x00,
        0x00, 0x6f, 0x70, 0x65, 0x6e, 0x36, 0x32, 0x35,
        0x34, 0x31, 0x2d, 0x61, 0x6e, 0x6f, 0x6e, 0x79,
        0x6d, 0x6f, 0x75, 0x73, 0x2d, 0x70, 0x6f, 0x6c,
        0x69, 0x63, 0x79, 0x00, 0x00, 0x00, 0x00, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0x19, 0x00, 0x00, 0x00, 0x6f,
        0x70, 0x65, 0x6e, 0x36, 0x32, 0x35, 0x34, 0x31,
        0x2d, 0x75, 0x73, 0x65, 0x72, 0x6e, 0x61, 0x6d,
        0x65, 0x2d, 0x70, 0x6f, 0x6c, 0x69, 0x63, 0x79,
        0x01, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x2f, 0x00, 0x00, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x6f,
        0x70, 0x63, 0x66, 0x6f, 0x75, 0x6e, 0x64, 0x61,
        0x74, 0x69, 0x6f, 0x6e, 0x2e, 0x6f, 0x72, 0x67,
        0x2f, 0x55, 0x41, 0x2f, 0x53, 0x65, 0x63, 0x75,
        0x72, 0x69, 0x74, 0x79, 0x50, 0x6f, 0x6c, 0x69,
        0x63, 0x79, 0x23, 0x4e, 0x6f, 0x6e, 0x65, 0x41,
        0x00, 0x00, 0x00, 0x68, 0x74, 0x74, 0x70, 0x3a,
        0x2f, 0x2f, 0x6f, 0x70, 0x63, 0x66, 0x6f, 0x75,
        0x6e, 0x64, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x2e,
        0x6f, 0x72, 0x67, 0x2f, 0x55, 0x41, 0x2d, 0x50,
        0x72, 0x6f, 0x66, 0x69, 0x6c, 0x65, 0x2f, 0x54,
        0x72, 0x61, 0x6e, 0x73, 0x70, 0x6f, 0x72, 0x74,
        0x2f, 0x75, 0x61, 0x74, 0x63, 0x70, 0x2d, 0x75,
        0x61, 0x73, 0x63, 0x2d, 0x75, 0x61, 0x62, 0x69,
        0x6e, 0x61, 0x72, 0x79, 0x00, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x00, 0x00, 0x00, 0x00
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
}
