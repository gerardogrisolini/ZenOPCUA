//
//  OPCUAFrame.swift
//  
//
//  Created by Gerardo Grisolini on 25/01/2020.
//

import Foundation
import NIO

public struct OPCUAFrameHead: Equatable {
    public var messageType: MessageTypes = .hello
    public var chunkType: ChunkTypes = .frame
    public var messageSize: UInt32 = 0
}

public struct OPCUAFrame: Equatable {
    public var head: OPCUAFrameHead
    public var body: [UInt8]
    
    public init(head: OPCUAFrameHead, body: [UInt8] = [UInt8]()) {
        self.head = head
        self.body = body
        self.head.messageSize = UInt32(body.count) + 8
    }
    
    var buffer: ByteBuffer {
        var byteBuffer = ByteBufferAllocator().buffer(capacity: body.count + 8)
        byteBuffer.writeString("\(head.messageType.rawValue)\(head.chunkType.rawValue)")
        byteBuffer.writeBytes(head.messageSize.bytes)
        byteBuffer.writeBytes(body)
        return byteBuffer
    }

    public static func == (lhs: OPCUAFrame, rhs: OPCUAFrame) -> Bool {
        lhs.head == rhs.head
    }
}
