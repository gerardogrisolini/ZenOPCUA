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
        //print(value)
        out.writeString("\(value.head.messageType.rawValue)\(value.head.chunkType.rawValue)")
        out.writeBytes(value.head.messageSize.bytes)
        out.writeBytes(value.body)
    }
}
