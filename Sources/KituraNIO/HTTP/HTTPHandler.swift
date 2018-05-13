/*
 * Copyright IBM Corporation 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import NIO
import NIOHTTP1
import LoggerAPI
import Foundation

public class HTTPHandler: ChannelInboundHandler {

    /// The HTTPServer instance on which this handler is installed
    var server: HTTPServer 

    /// The serverRequest related to this handler instance
    var serverRequest: HTTPServerRequest!

    /// The serverResponse related to this handler instance
    var serverResponse: HTTPServerResponse!

    /// We'd want to send an error response only once
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
                serverRequest.buffer = BufferList(with: buffer)
            } else {
                serverRequest.buffer!.byteBuffer.write(buffer: &buffer)
            }
        case .end(_):
            serverResponse = HTTPServerResponse(ctx: ctx, handler: self)
            //Make sure we use the latest delegate registered with the server
            if let delegate = server.delegate {
                Monitor.delegate?.started(request: serverRequest, response: serverResponse)
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
           } catch { 
              Log.error("Failed to send error response")
           }
       }
    }

    func updateKeepAliveState() {
        keepAliveState.decrement()
    }
}
