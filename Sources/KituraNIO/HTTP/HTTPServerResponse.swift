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
        headers["Date"] = [SPIUtils.httpDate()]
    } 

    public func write(from string: String) throws {
        if buffer == nil {
            buffer = ctx.channel.allocator.buffer(capacity: 1024)
        }
        buffer!.write(string: string)
    }
    
    public func write(from data: Data) throws {
        if buffer == nil {
            buffer = ctx.channel.allocator.buffer(capacity: 1024)
         }
        buffer!.write(bytes: data)
    }
    
    public func end(text: String) throws {
        //TODO: Forced unwrapping
        try write(from: text)
        try end()
    }
    
    public func end() throws {
        let status = HTTPResponseStatus(statusCode: statusCode?.rawValue ?? 0)
        if self.handler.clientRequestedKeepAlive {
            headers["Connection"] = ["Keep-Alive"]
            if let maxConnections = self.handler.keepAliveState.requestsRemaining {
                headers["Keep-Alive"] = ["timeout=\(HTTPHandler.keepAliveTimeout), max=\(Int(maxConnections))"]
            } else {
                headers["Keep-Alive"] = ["timeout=\(HTTPHandler.keepAliveTimeout)"]
            }
        }

        let response = HTTPResponseHead(version: httpVersion, status: status, headers: headers.httpHeaders())
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        if let buffer = buffer {
            ctx.write(handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        ctx.writeAndFlush(handler.wrapOutboundOut(.end(nil)), promise: nil)
        handler.updateKeepAliveState()
    }

    

    func end(with errorCode: HTTPStatusCode) throws {
        self.statusCode = errorCode
        let status = HTTPResponseStatus(statusCode: errorCode.rawValue)
        //We don't keep the connection alive on an HTTP error
        headers["Connection"] = ["Close"]
        let response = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: status, headers: headers.httpHeaders())
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        ctx.writeAndFlush(handler.wrapOutboundOut(.end(nil)), promise: nil)
        handler.updateKeepAliveState()
    }
 
    public func reset() { //TODO 
    }
}
