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
import LoggerAPI
import Foundation

// MARK: HTTPServerResponse
/**
This class implements the `ServerResponse` protocol for outgoing server
responses via the HTTP protocol. Data and Strings can be written.

The example below uses this in its `response` parameter, with the example requesting a connection be upgraded and catch any errors that occur.
### Usage Example: ###
````swift
 func upgradeConnection(handler: IncomingSocketHandler, request: ServerRequest, response: ServerResponse) {
     guard let protocols = request.headers["Upgrade"] else {
         do {
             response.statusCode = HTTPStatusCode.badRequest
             try response.write(from: "No protocol specified in the Upgrade header")
             try response.end()
         }
         catch {
             Log.error("Failed to send error response to Upgrade request")
         }
         return
     }
 }
````
*/
public class HTTPServerResponse: ServerResponse {

    /// The channel to which the HTTP response should be written
    private weak var channel: Channel?

    /// The handler that processed the HTTP request
    private weak var handler: HTTPRequestHandler?

    /// Status code
    private var status = HTTPStatusCode.OK.rawValue

    /**
    HTTP status code of the response.

    ### Usage Example: ###
    ````swift
    ServerResponse.statusCode = HTTPStatusCode.badRequest
    ````
    */
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

    /**
    The HTTP headers to be sent to the client as part of the response.

    ### Usage Example: ###
    ````swift
    ServerResponse.headers["Content-Type"] = ["text/plain"]
    ````
    */
    public var headers: HeadersContainer = HeadersContainer()

    /// The HTTP version to be sent in the response.
    private var httpVersion: HTTPVersion

    /// The data to be written as a part of the response.
    private var buffer: ByteBuffer

    /// Initial size of the response buffer (inherited from KituraNet)
    private static let bufferSize = 2000

    init(channel: Channel, handler: HTTPRequestHandler) {
        self.channel = channel
        self.handler = handler
        self.buffer = channel.allocator.buffer(capacity: HTTPServerResponse.bufferSize)
        let httpVersionMajor = Int(handler.serverRequest?.httpVersionMajor ?? 1)
        let httpVersionMinor = Int(handler.serverRequest?.httpVersionMinor ?? 1)
        self.httpVersion = HTTPVersion(major: httpVersionMajor, minor: httpVersionMinor)
        headers["Date"] = [SPIUtils.httpDate()]
    }

    /**
    Write a string as a response.

    - Parameter from: String data to be written.
    - Throws: Socket.error if an error occurred while writing to a socket.

    ### Usage Example: ###
    ````swift
     try ServerResponse.write(from: "Some string")
    ````
    */
    public func write(from string: String) throws {
        guard let channel = channel else {
            // The connection was probably closed by the client, subsequently the Channel was closed, deregistered from the EventLoop and deallocated.
            // TODO: We must be throwing an error from here, for which we'd need to add a new Error type to the API
            return
        }

        channel.eventLoop.run {
            self.buffer.writeString(string)
        }
    }

    /**
    Write data as a response.

    - Parameter from: Data object that contains the data to be written.
    - Throws: Socket.error if an error occurred while writing to a socket.

    ### Usage Example: ###
    ````swift
    try ServerResponse.write(from: someData)
    ````
    */
    public func write(from data: Data) throws {
        guard let channel = channel else {
            // The connection was probably closed by the client, subsequently the Channel was closed, deregistered from the EventLoop and deallocated.
            // TODO: We must be throwing an error from here, for which we'd need to add a new Error type to the API.
            return
        }

        channel.eventLoop.run {
            self.buffer.writeBytes(data)
        }
    }

    /**
    Write a String to the body of a HTTP response and complete sending the HTTP response.

    - Parameter text: String to write to a socket.
    - Throws: Socket.error if an error occurred while writing to a socket.

    ### Usage Example: ###
    ````swift
    try ServerResponse.end("Some string")
    ````
    */
    public func end(text: String) throws {
        try write(from: text)
        try end()
    }

    /**
    Complete sending the HTTP response.

    - Throws: Socket.error if an error occurred while writing to a socket.

    ### Usage Example: ###
    ````swift
    try ServerResponse.end()
    ````
    */
    public func end() throws {
        guard let channel = self.channel else {
            // The connection was probably closed by the client, subsequently the Channel was closed, deregistered from the EventLoop and deallocated.
            // TODO: We must be throwing an error from here, for which we'd need to add a new Error type to the API.
            return
        }

        guard let handler = self.handler else {
            // A deallocated channel handler suggests the pipeline and the channel were also de-allocated. The connection was probably closed.
            // TODO: We must be throwing an error from here, for which we'd need to add a new Error type to the API.
            return
        }

        let status = HTTPResponseStatus(statusCode: statusCode?.rawValue ?? 0)
        if handler.clientRequestedKeepAlive {
            headers["Connection"] = ["Keep-Alive"]
            if let maxConnections = handler.keepAliveState.requestsRemaining {
                headers["Keep-Alive"] = ["timeout=\(HTTPRequestHandler.keepAliveTimeout), max=\(Int(maxConnections))"]
            } else {
                headers["Keep-Alive"] = ["timeout=\(HTTPRequestHandler.keepAliveTimeout)"]
            }
        }

        channel.eventLoop.run {
            do {
                try self.sendResponse(channel: channel, handler: handler, status: status)
            } catch let error {
                Log.error("Error sending response: \(error)")
                // TODO: We must be rethrowing/throwing from here, for which we'd need to add a new Error type to the API
            }
        }
    }

    // End sending the response on an HTTP error
    private func end(with errorCode: HTTPStatusCode, withBody: Bool = false) throws {
        guard let channel = self.channel else {
            // The connection was probably closed by the client, subsequently the Channel was closed, deregistered from the EventLoop and deallocated.
            // TODO: We must be throwing an error from here, for which we'd need to add a new Error type to the API
            return
        }

        guard let handler = self.handler else {
            // A deallocated channel handler suggests the pipeline and the channel were also de-allocated. The connection was probably closed.
            // TODO: We must be throwing an error from here, for which we'd need to add a new Error type to the API
            return
        }

        self.statusCode = errorCode
        let status = HTTPResponseStatus(statusCode: errorCode.rawValue)

        //We don't keep the connection alive on an HTTP error
        headers["Connection"] = ["Close"]

        // We want to close this channel after the error response is sent
        let responseSentPromise = channel.eventLoop.makePromise(of: Void.self)
        channel.eventLoop.run {
            do {
                try self.sendResponse(channel: channel, handler: handler, status: status, withBody: withBody, promise: responseSentPromise)
            } catch let error {
                Log.error("Error sending response: \(error)")
                //TODO: We must be rethrowing/throwing from here, for which we'd need to add a new Error type to the API
            }
            responseSentPromise.futureResult.whenComplete { _ in
                channel.close(promise: nil)
            }
        }
    }

    /// Send response to the client
    private func sendResponse(channel: Channel, handler: HTTPRequestHandler, status: HTTPResponseStatus, withBody: Bool = true, promise: EventLoopPromise<Void>? = nil) throws {
        let response = HTTPResponseHead(version: httpVersion, status: status, headers: headers.nioHeaders)
        channel.write(handler.wrapOutboundOut(.head(response)), promise: nil)
        if withBody && buffer.readableBytes > 0 {
            channel.write(handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }

        channel.writeAndFlush(handler.wrapOutboundOut(.end(nil)), promise: promise)
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

    /**
    Reset this response object back to its initial state.

    ### Usage Example: ###
    ````swift
    try ServerResponse.reset()
    ````
    */
    public func reset() {
        status = HTTPStatusCode.OK.rawValue
        buffer.clear()
        headers.removeAll()
        headers["Date"] = [SPIUtils.httpDate()]
    }
}

extension EventLoop {
    /// Make sure `task` runs on the current event loop
    @discardableResult
    func run(_ task: @escaping () -> Void) -> EventLoopFuture<Void>? {
        if self.inEventLoop {
            task()
            return nil
        } else {
            return self.submit {
                task()
            }
        }
    }
}
