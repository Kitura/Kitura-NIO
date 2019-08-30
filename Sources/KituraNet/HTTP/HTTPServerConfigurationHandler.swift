import NIO
import NIOHTTP1
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch
import NIOConcurrencyHelpers

internal class HTTPServerConfigurationHandler: ChannelDuplexHandler {
    // The HTTPServer instance on which this handler is installed
    var server: HTTPServer
    let requestSizeLimit: Int?
    let connectionLimit: Int?
    var requestSize: Int = 0
    var connectionCount = 0
    typealias InboundIn = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    public init(for server: HTTPServer) {
        self.server = server
//        if let requestSizeLimit = server.serverConfig.requestSizeLimit {
//            self.requestSizeLimit = requestSizeLimit
//        }
//        if let connectionLimit = server.serverConfig.connectionLimit {
//            self.connectionLimit = connectionLimit
//        }
        self.requestSizeLimit = server.serverConfig.requestSizeLimit ?? nil
        self.connectionLimit = server.serverConfig.connectionLimit ?? nil
    }
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        requestSize = requestSize + data.readableBytes
        if let requestSizeLimit1 = requestSizeLimit {
            if requestSize > requestSizeLimit1 {
                let statusDescription = HTTP.statusCodes[HTTPStatusCode.requestTooLong.rawValue] ?? ""
                var discriptionBuffer = ByteBufferAllocator().buffer(capacity: requestSizeLimit!)
                discriptionBuffer.writeString(statusDescription)
                context.writeAndFlush(NIOAny(discriptionBuffer),promise: nil)
                requestSize = 0
                context.close(mode: .all, promise: nil)
                return
            }
        }
        context.fireChannelRead(wrapInboundOut(data))
    }
    
    public func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        requestSize = event as? Int ?? 0
    }
    public func channelActive(context: ChannelHandlerContext) {
        _ = server.connectionCount.add(1)
        if let connectionLimit1 = connectionLimit {
            if server.connectionCount.load() > connectionLimit1{
                let statusDescription = HTTP.statusCodes[HTTPStatusCode.serviceUnavailable.rawValue] ?? ""
                var statusBuffer = ByteBufferAllocator().buffer(capacity: 1024)
                statusBuffer.writeString(statusDescription)
                context.writeAndFlush(NIOAny(statusBuffer),promise: nil)
                _ = server.connectionCount.sub(1)
                context.close(mode: .all, promise: nil)
                return
            }
        }
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        _ = server.connectionCount.sub(1)
        context.fireChannelInactive()
    }
}


