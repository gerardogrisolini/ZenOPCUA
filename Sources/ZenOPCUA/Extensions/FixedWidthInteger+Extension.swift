//
//  FixedWidthInteger+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

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

    internal var bytes: [UInt8] {
        var _endian = littleEndian
        let bytePtr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Self>.size) {
                UnsafeBufferPointer(start: $0, count: MemoryLayout<Self>.size)
            }
        }
        return [UInt8](bytePtr)
    }
}
