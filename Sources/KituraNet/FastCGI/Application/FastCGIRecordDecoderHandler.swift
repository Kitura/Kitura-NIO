//
//  FastCGIRecordDecoder.swift
//  KituraNet
//
//  Created by Rudrani Wankhade on 27/01/20.
//

import NIO
import NIOFoundationCompat
import Foundation

class FastCGIRecordDecoderHandler<Decoder: FastCGIRecordDecoder>: ChannelInboundHandler {
    
    typealias InboundIn = ByteBuffer
    typealias InboundOut = FastCGIRecord

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        let requestData = request.getData(at: 0, length: request.readableBytes)
        try! Decoder.decode(from: Decoder.unwrap(requestData)).forEach {
            context.fireChannelRead(self.wrapInboundOut($0))
        }
    }
}
