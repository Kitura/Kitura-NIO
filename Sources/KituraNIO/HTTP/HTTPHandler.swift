import NIO
import NIOHTTP1

public class HTTPHandler: ChannelInboundHandler {
     let router: ServerDelegate 
     var serverRequest: HTTPServerRequest!
     var serverResponse: HTTPServerResponse!

     public init(router: ServerDelegate) {
         self.router = router
     }

     public typealias InboundIn = HTTPServerRequestPart
     public typealias OutboundOut = HTTPServerResponsePart

     public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
         let request = self.unwrapInboundIn(data)

         switch request {
         case .head(let header):
             serverRequest = HTTPServerRequest(ctx: ctx, requestHead: header)
         case .body(let buffer):
             serverRequest.buffer = buffer           
         case .end(_):
             serverResponse = HTTPServerResponse(ctx: ctx, handler: self)
             router.handle(request: serverRequest, response: serverResponse)
         }
     }
}
