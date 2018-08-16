/*
 * Copyright IBM Corporation 2016, 2017, 2018
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
import Foundation

/// This class implements the `ServerResponse` protocol for outgoing server
/// responses via the HTTP protocol.
public class HTTPServerResponse: ServerResponse {

    /// The channel handler context on which an HTTP response should be written
    private weak var ctx: ChannelHandlerContext?

    /// The handler that processed the HTTP request
    private weak var handler: HTTPHandler?

    /// Status code
    private var status = HTTPStatusCode.OK.rawValue

    /// HTTP status code of the response.
    public var statusCode: HTTPStatusCode? {
        get {
            return HTTPStatusCode(rawValue: status)
        }

        set (newValue) {
            if let newValue = newValue {
                status = newValue.rawValue
            }
        } 
    }

    /// The HTTP headers to be sent to the client as part of the response.
    public var headers : HeadersContainer = HeadersContainer()


    /// The HTTP version to be sent in the response.
    private var httpVersion: HTTPVersion

    /// The data to be written as a part of the response.
    private var buffer: ByteBuffer?
    
    init(ctx: ChannelHandlerContext, handler: HTTPHandler) {
        self.ctx = ctx
        self.handler = handler
        let httpVersionMajor = handler.serverRequest?.httpVersionMajor ?? 0
        let httpVersionMinor = handler.serverRequest?.httpVersionMinor ?? 0
        self.httpVersion = HTTPVersion(major: httpVersionMajor, minor: httpVersionMinor)
        headers["Date"] = [SPIUtils.httpDate()]
    } 

    /// Write a string as a response.
    ///
    /// - Parameter from: String data to be written.
    public func write(from string: String) throws {
        guard let ctx = ctx else {
            fatalError("No channel handler context available.")
        }
        if buffer == nil {
            buffer = ctx.channel.allocator.buffer(capacity: string.utf8.count)
        }
        buffer!.write(string: string)
    }

    /// Write data as a response.
    ///
    /// - Parameter from: Data object that contains the data to be written.
    public func write(from data: Data) throws {
        guard let ctx = ctx else {
            fatalError("No channel handler context available.")
        }
        if buffer == nil {
            buffer = ctx.channel.allocator.buffer(capacity: data.count)
         }
        buffer!.write(bytes: data)
    }

    /// Write a string and end sending the response.
    ///
    /// - Parameter text: String to write to a socket.
    public func end(text: String) throws {
        try write(from: text)
        try end()
    }

    /// End sending the response.
    ///
    public func end() throws {
        guard let ctx = self.ctx else {
            fatalError("No channel handler context available.")
        }

        guard let handler = self.handler else {
            fatalError("No HTTP handler available")
        }

        let status = HTTPResponseStatus(statusCode: statusCode?.rawValue ?? 0)
        if handler.clientRequestedKeepAlive {
            headers["Connection"] = ["Keep-Alive"]
            if let maxConnections = handler.keepAliveState.requestsRemaining {
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

        if let request = handler.serverRequest {
            Monitor.delegate?.finished(request: request, response: self)
        }
    }

    /// End sending the response on an HTTP error
    private func end(with errorCode: HTTPStatusCode, withBody: Bool = false) throws {
        guard let ctx = self.ctx else {
            fatalError("No channel handler context available.")
        }

        guard let handler = self.handler else {
            fatalError("No HTTP handler available")
        }

        self.statusCode = errorCode
        let status = HTTPResponseStatus(statusCode: errorCode.rawValue)

        //We don't keep the connection alive on an HTTP error
        headers["Connection"] = ["Close"]
        let response = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1), status: status, headers: headers.httpHeaders())
        ctx.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        if withBody && buffer != nil {
            ctx.write(handler.wrapOutboundOut(.body(.byteBuffer(buffer!))), promise: nil)
        }
        ctx.writeAndFlush(handler.wrapOutboundOut(.end(nil)), promise: nil)
        handler.updateKeepAliveState()

        if let request = handler.serverRequest {
                Monitor.delegate?.finished(request: request, response: self)
        }
    }

    func end(with errorCode: HTTPStatusCode, message: String? = nil) throws {
        if let message = message {
            try write(from: message)
        }
        try end(with: errorCode, withBody: message != nil)
    }

    /// Reset this response object back to its initial state
    public func reset() {
        status = HTTPStatusCode.OK.rawValue
        if buffer != nil {
            buffer!.clear()
        }
        headers.removeAll()
        headers["Date"] = [SPIUtils.httpDate()]
    }
}
