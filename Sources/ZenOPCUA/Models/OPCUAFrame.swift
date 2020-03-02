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

extension String: OPCUAEncodable {
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

//* An instance in time. A DateTime value is encoded as a 64-bit signed integer
//* which represents the number of 100 nanosecond intervals since January 1, 1601
//* (UTC).

extension Date : OPCUAEncodable {
    var ticks: Int64 {
        let calendar = Calendar.current
        let dstComponents = DateComponents(year: 1601,
            month: 1,
            day: 1)
        if #available(OSX 10.12, *) {
            let interval = DateInterval(start: calendar.date(from: dstComponents)!, end: self).duration
            return Int64(TimeInterval(interval * 10000000))
        } else {
            return 0
        }
    }

    var bytes: [UInt8] {
        return ticks.bytes
    }
}

extension Int64: OPCUAEncodable{
    var date: Date {
        let dstComponents = DateComponents(year: 1601,
            month: 1,
            day: 1)
        let start = Calendar.current.date(from: dstComponents)!
        return Date(timeInterval: TimeInterval(self / 1000), since: start)
    }

    var dateUtc: Date {
        let dstComponents = DateComponents(year: 1601,
            month: 1,
            day: 1)
        let start = Calendar.current.date(from: dstComponents)!
        return Date(timeInterval: TimeInterval(self / 10000000), since: start)
    }
}

extension FixedWidthInteger {
    init<I>(littleEndianBytes iterator: inout I) where I: IteratorProtocol, I.Element == UInt8 {
        self = stride(from: 0, to: Self.bitWidth, by: 8).reduce(into: 0) {
          $0 |= Self(truncatingIfNeeded: iterator.next()!) &<< $1
        }
    }

    init<C>(bytes: C) where C: Collection, C.Element == UInt8 {
        precondition(bytes.count == (Self.bitWidth+7)/8)
        var iter = bytes.makeIterator()
        self.init(littleEndianBytes: &iter)
    }

    var bytes: [UInt8] {
        var _endian = littleEndian
        let bytePtr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Self>.size) {
                UnsafeBufferPointer(start: $0, count: MemoryLayout<Self>.size)
            }
        }
        return [UInt8](bytePtr)
    }
}

extension UInt16: OPCUAEncodable {
}

extension Double: OPCUAEncodable, OPCUADecodable {
    init(bytes: [UInt8]) {
        precondition(bytes.count == 8)
        self = bytes.withUnsafeBytes{ $0.load(as: Double.self) }
    }

    var bytes: [UInt8] {
        var _self = self
        let bytePtr = withUnsafePointer(to: &_self) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Self>.size) {
                UnsafeBufferPointer(start: $0, count: MemoryLayout<Self>.size)
            }
        }
        return [UInt8](bytePtr)
    }
}

extension Bool {
    init(byte: UInt8) {
        self = byte == 0x01 ? true : false
    }

    var bytes: [UInt8] {
        return [self ? 0x01 : 0x00]
    }
}

extension Array where Element: OPCUAEncodable {
    var bytes: [UInt8] {
        return self.map { $0.bytes }.reduce([], +)
    }
}
