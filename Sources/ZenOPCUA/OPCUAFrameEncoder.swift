//
//  OPCUAFrameEncoder.swift
//  
//
//  Created by Gerardo Grisolini on 26/01/2020.
//

import NIO

public final class OPCUAFrameEncoder: MessageToByteEncoder {
    public typealias OutboundIn = OPCUAFrame

    public func encode(data value: OPCUAFrame, out: inout ByteBuffer) throws {
        out.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
        out.writeBytes(value.head.messageSize.bytes)
        out.writeBytes(value.body)
    }
}

extension FixedWidthInteger where Self: UnsignedInteger {
    init<I>(littleEndianBytes iterator: inout I) where I: IteratorProtocol, I.Element == UInt8 {
        self = stride(from: 0, to: Self.bitWidth, by: 8).reduce(into: 0) {
          $0 |= Self(truncatingIfNeeded: iterator.next()!) &<< $1
        }
    }
      
    init<C>(littleEndianBytes bytes: C) where C: Collection, C.Element == UInt8 {
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

extension Bool {
    init(byte: UInt8) {
        self = byte == 0x01 ? true : false
    }

    var bytes: [UInt8] {
        return [self ? 0x01 : 0x00]
    }
}
