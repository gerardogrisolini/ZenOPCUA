//
//  OPCUAFrame.swift
//  
//
//  Created by Gerardo Grisolini on 25/01/2020.
//

import Foundation
import NIO

public struct OPCUAFrameHead: Equatable, Sendable {
    public var messageType: MessageTypes = .hello
    public var chunkType: ChunkTypes = .frame
    public var messageSize: UInt32 = 0
}

public struct OPCUAFrame: Equatable, Sendable {
    public var head: OPCUAFrameHead
    public var body: [UInt8]
    
    public init(head: OPCUAFrameHead, body: [UInt8] = [UInt8]()) {
        self.head = head
        self.body = body
        // Calculate message size safely, checking for overflow
        let totalSize = body.count + 8
        if totalSize > Int(UInt32.max) || totalSize < 0 {
            self.head.messageSize = UInt32.max
        } else {
            self.head.messageSize = UInt32(totalSize)
        }
    }
    
    var buffer: ByteBuffer {
        let capacity = max(0, body.count + 8)
        var byteBuffer = ByteBufferAllocator().buffer(capacity: capacity)
        byteBuffer.writeString("\(head.messageType.rawValue)\(head.chunkType.rawValue)")
        byteBuffer.writeBytes(head.messageSize.bytes)
        byteBuffer.writeBytes(body)
        return byteBuffer
    }

    public static func == (lhs: OPCUAFrame, rhs: OPCUAFrame) -> Bool {
        lhs.head == rhs.head
    }
}
