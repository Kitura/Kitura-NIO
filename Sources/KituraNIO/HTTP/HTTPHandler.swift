import NIO
import NIOHTTP1
import Foundation

public class HTTPHandler: ChannelInboundHandler {

    var server: HTTPServer 

    var serverRequest: HTTPServerRequest!

    var serverResponse: HTTPServerResponse!

    var errorResponseSent = false

    var keepAliveState: KeepAliveState = .unlimited
   
    static let keepAliveTimeout: TimeInterval = 60
  
    private(set) var clientRequestedKeepAlive = false

    private(set) var enableSSLVerfication = false

    public init(for server: HTTPServer) { 
        self.server = server
        self.keepAliveState = server.keepAliveState
        if let _ = server.sslConfig {
            self.enableSSLVerfication = true
        }
    }

    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)

        switch request {
        case .head(let header):
            serverRequest = HTTPServerRequest(ctx: ctx, requestHead: header, enableSSL: enableSSLVerfication)
            self.clientRequestedKeepAlive = header.isKeepAlive
        case .body(var buffer):
            if serverRequest.buffer == nil {
                serverRequest.buffer = buffer
            } else {
                serverRequest.buffer!.write(buffer: &buffer)
            }
        case .end(_):
            serverResponse = HTTPServerResponse(ctx: ctx, handler: self)
            //Make sure we use the latest delegate registered with the server
            if let delegate = server.delegate {
                delegate.handle(request: serverRequest, response: serverResponse)
            } //TODO: failure path
        }
    }

    //IdleStateEvents are received on this method
    public func userInboundEventTriggered(ctx: ChannelHandlerContext, event: Any) {
        if event is IdleStateHandler.IdleStateEvent {
            _ = ctx.close()
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
    }
}
