//
//  OPCUAFrameCodecHandler.swift
//
//
//  Created by Gerardo Grisolini on 11/02/2026.
//

import NIO

// Concurrency: confined to the channel's EventLoop.
final class OPCUAFrameCodecHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = OPCUAFrame
    typealias OutboundIn = OPCUAFrame
    typealias OutboundOut = ByteBuffer

    private let decoder: OPCUAFrameDecoder
    private let encoder: OPCUAFrameEncoder

    init(state: OPCUAConnectionState) {
        self.decoder = OPCUAFrameDecoder(state: state)
        self.encoder = OPCUAFrameEncoder(state: state)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        decoder.appendInboundBuffer(&buffer)
        do {
            while let frame = try decoder.decodeNextFrame() {
                context.fireChannelRead(wrapInboundOut(frame))
            }
        } catch {
            context.fireErrorCaught(error)
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let frame = unwrapOutboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: 0)
        do {
            try encoder.encode(frame: frame, out: &buffer)
            context.write(wrapOutboundOut(buffer), promise: promise)
        } catch {
            promise?.fail(error)
            context.fireErrorCaught(error)
        }
    }
}
