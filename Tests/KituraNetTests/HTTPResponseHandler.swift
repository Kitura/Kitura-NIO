import NIO
import NIOHTTP1
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch

internal class HTTPResponseHandler: ChannelInboundHandler {
    /// The ClientResponse object for the response
    internal var statusCode: HTTPResponseStatus = .ok
    typealias InboundIn = HTTPServerResponsePart
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let header):
            statusCode = header.status
        default:
            break
        }
    }
}

