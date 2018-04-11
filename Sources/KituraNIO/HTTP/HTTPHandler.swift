import NIO
import NIOHTTP1
import Foundation

public class HTTPHandler: ChannelInboundHandler {
    var delegate: ServerDelegate!
    var serverRequest: HTTPServerRequest!
    var serverResponse: HTTPServerResponse!
    var errorResponseSent = false

    var keepAliveState: KeepAliveState = .unlimited
   
    static let keepAliveTimeout: TimeInterval = 60
  
    private(set) var clientRequestedKeepAlive = false

    var keepAliveUntil: TimeInterval = 0.0

    public init() { }

    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)

        switch request {
        case .head(let header):
            serverRequest = HTTPServerRequest(ctx: ctx, requestHead: header)
            self.clientRequestedKeepAlive = header.isKeepAlive
        case .body(var buffer):
            if serverRequest.buffer == nil {
                serverRequest.buffer = buffer
            } else {
                serverRequest.buffer!.write(buffer: &buffer)
            }
        case .end(_):
            serverResponse = HTTPServerResponse(ctx: ctx, handler: self)
            delegate.handle(request: serverRequest, response: serverResponse)
         }
     }

     public func channelReadComplete(ctx: ChannelHandlerContext) {
         ctx.flush()
     }

     public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
         //Check for parser errors
         guard !errorResponseSent else { return }
         if error is HTTPParserError {
            do {
               errorResponseSent = true
               serverResponse = HTTPServerResponse(ctx: ctx, handler: self)
               try serverResponse.end(with: .badRequest)
            } catch { }
        }
    }

    func updateKeepAliveState() {
        keepAliveState.decrement()
        keepAliveUntil = Date(timeIntervalSinceNow: HTTPHandler.keepAliveTimeout).timeIntervalSinceReferenceDate
    }
}
