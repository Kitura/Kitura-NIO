//
//  FastCGIRecordEncoder.swift
//  KituraNet
//
//  Created by Rudrani Wankhade on 22/01/20.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

internal class FastCGIRecordEncoderHandler<Encoder: FastCGIEncoder>: ChannelOutboundHandler {
    
    typealias OutboundIn = FastCGIRecord
    typealias OutboundOut = ByteBuffer

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let record = unwrapOutboundIn(data)
        let encoder = Encoder(record)
        let data = try! encoder.encode() as! Data
        var buffer = context.channel.allocator.buffer(capacity: data.count )
        buffer.writeBytes(data)
            context.write(self.wrapOutboundOut(buffer), promise: promise)
        }

        public func flush(context: ChannelHandlerContext) {
            context.flush()
        }

}
