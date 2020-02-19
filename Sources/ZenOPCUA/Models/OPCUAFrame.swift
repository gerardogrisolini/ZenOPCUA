//
//  OPCUAFrame.swift
//  
//
//  Created by Gerardo Grisolini on 25/01/2020.
//

import Foundation


public struct OPCUAFrameHead: Equatable {
    public var messageType: MessageTypes = .hello
    public var chunkType: ChunkTypes = .frame
    public var messageSize: UInt32 = 8
}

public struct OPCUAFrame: Equatable {
    public var head: OPCUAFrameHead
    public var body: [UInt8]
    
    public init(head: OPCUAFrameHead, body: [UInt8] = [UInt8]()) {
        self.head = head
        self.body = body
        self.head.messageSize += UInt32(body.count)
    }

    public static func == (lhs: OPCUAFrame, rhs: OPCUAFrame) -> Bool {
        lhs.head == rhs.head
    }
}

extension String {
    var bytes: [UInt8] {
        let len = self.isEmpty ? UInt32.max : UInt32(self.utf8.count)
        return len.bytes + self.utf8.map { $0 }
    }
}

extension Optional where Wrapped == String {
    var bytes: [UInt8] {
        self == nil ? UInt32.max.bytes : self!.bytes
    }
}

extension Date : OPCUAEncodable {
    var ticks: UInt64 {
        return UInt64((self.timeIntervalSince1970 + 62_135_596_800) * 10_000_000)
    }

    var bytes: [UInt8] {
        return ticks.bytes
    }
}

extension UInt64 {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(self/1000))
    }
}
