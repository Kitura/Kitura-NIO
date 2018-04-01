import NIO
import NIOHTTP1
import Foundation

public class HTTPServerResponse: ServerResponse {
   
    private let ctx: ChannelHandlerContext 
    private let handler: HTTPHandler 
 
    public var statusCode: HTTPStatusCode?
    
    public var headers : HeadersContainer = HeadersContainer()

    private var httpVersion: HTTPVersion
    
    private var buffer: ByteBuffer?
    
    init(ctx: ChannelHandlerContext, handler: HTTPHandler) {
        self.ctx = ctx
        self.handler = handler
        let httpVersionMajor = handler.serverRequest?.httpVersionMajor ?? 0
        let httpVersionMinor = handler.serverRequest?.httpVersionMinor ?? 0
        self.httpVersion = HTTPVersion(major: httpVersionMajor, minor: httpVersionMinor)
    } 

    public func write(from string: String) throws {
        try write(from: string.data(using: .utf8)!)
    }
    
    public func write(from data: Data) throws {
        if buffer == nil {
            buffer = ctx.channel.allocator.buffer(capacity: 1024)
         }
        buffer!.append(data: data)
    }
    
    public func end(text: String) throws {
        //TODO: Forced unwrapping
        try write(from: text)
        try end()
    }
    
    public func end() throws {
        let status = HTTPResponseStatus(statusCode: statusCode?.rawValue ?? 0)
        let response = HTTPResponseHead(version: httpVersion, status: status, headers: headers.httpHeaders())
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        if let buffer = buffer {
            ctx.write(handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        ctx.write(handler.wrapOutboundOut(.end(nil)), promise: nil) //TODO: .end(nil) for now!
        ctx.flush()
    }

    func end(with errorCode: HTTPStatusCode) throws {
        self.statusCode = errorCode
        let status = HTTPResponseStatus(statusCode: errorCode.rawValue)
        let response = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: status, headers: HTTPHeaders())
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        ctx.writeAndFlush(handler.wrapOutboundOut(.end(nil)), promise: nil)
        ctx.close(promise:nil)
    }
 
    public func reset() { //TODO 
    }
}
