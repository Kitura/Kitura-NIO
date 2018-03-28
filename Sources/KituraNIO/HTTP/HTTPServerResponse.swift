import NIO
import NIOHTTP1
import Foundation

public class HTTPServerResponse: ServerResponse {
   
    private let ctx: ChannelHandlerContext 
    private let handler: HTTPHandler 
 
    public var statusCode: HTTPStatusCode?
    
    public var headers : HeadersContainer = HeadersContainer()
    
    init(ctx: ChannelHandlerContext, handler: HTTPHandler) {
        self.ctx = ctx
        self.handler = handler
    } 

    public func write(from string: String) throws {
        try write(from: string.data(using: .utf8)!)
    }
    
    public func write(from data: Data) throws {
        var buffer = ctx.channel.allocator.buffer(capacity: 1024)
        //TODO: Fix forced unwrapping here
        buffer.write(string: String(data: data, encoding: .utf8)!)
        let request = handler.serverRequest!
        let version = HTTPVersion(major: request.httpVersionMajor!, minor: request.httpVersionMinor!)
        let response = HTTPResponseHead(version: version, status: .ok, headers: headers.httpHeaders())
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        ctx.write(handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        ctx.write(handler.wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    public func end(text: String) throws {
        //TODO: Forced unwrapping
        try write(from: text)
        ctx.flush()
    }
    
    public func end() throws {
        ctx.flush()
    }
    
    public func reset() { //TODO 
    }
}
