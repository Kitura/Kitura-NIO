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

import Foundation
import NIO

/// The FastCGIServerRequest class implements the `ServerResponse` protocol
/// for incoming HTTP requests that come in over a FastCGI connection.
public class FastCGIServerResponse: ServerResponse {

    /// Size of buffers (64 * 1024 is the max size for a FastCGI outbound record)
    /// Which also gives a bit more internal buffer room.
    private static let bufferSize = 64 * 1024

    /// Buffer for HTTP response line, headers, and short bodies
    private var buffer = Data(capacity: FastCGIServerResponse.bufferSize)

    /// Whether or not the HTTP response line and headers have been flushed.
    private var startFlushed = false

    /// The headers to send back as part of the HTTP response.
    public var headers = HeadersContainer()

    /// Status code
    private var status = HTTPStatusCode.OK.rawValue

    /// Corresponding server request
    private weak var serverRequest: FastCGIServerRequest?

    /// The status code to send in the HTTP response.
    public var statusCode: HTTPStatusCode? {
        get {
            return HTTPStatusCode(rawValue: status)
        }
        set (newValue) {
            if let newValue = newValue, !startFlushed {
                status = newValue.rawValue
            }
        }
    }

    private let channel: Channel
    private let handler: FastCGIRequestHandler
    private let keepAlive: Bool
    
    init(channel: Channel, handler: FastCGIRequestHandler, keepAlive: Bool) {
        self.channel = channel
        self.handler = handler
        self.keepAlive = keepAlive
        headers["Date"] = [SPIUtils.httpDate()]
    }

    public func end(text: String) throws {
        try write(from: text)
        try end()
    }

    public func write(from string: String) throws {
        try write(from: string.data(using: .utf8)!)
    }

    public func write(from data: Data) throws {
        buffer.append(data)
    }

    private func startResponse() {
        var headerData = ""

        // add our status header for FastCGI
        headerData.append("HTTP/1.1 \(status) \(HTTP.statusCodes[status]!)\r\n")

        // add the rest of our response headers
        for (name, value) in headers.nioHeaders {
            headerData.append(name)
            headerData.append(": ")
            headerData.append(value)
            headerData.append("\r\n")
        }

        headerData.append("\r\n")

        var data = headerData.data(using: .utf8)!
        data.append(buffer)
        let record = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION,
                                   type: .stdout,
                                   requestId: self.handler.serverRequest?.requestId ?? 0,
                                   content: .data(data))
        _ = channel.writeAndFlush(handler.wrapOutboundOut(record))
    }

    public func end() throws {
        startResponse()
        let emptyRecord = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION, 
                                        type: .stdout,
                                        requestId: self.handler.serverRequest?.requestId ?? 0,  
                                        content: .data(Data()))
         _ = channel.write(handler.wrapOutboundOut(emptyRecord))

        let endRequestRecord = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION, 
                                             type: .endRequest,
                                             requestId: self.handler.serverRequest?.requestId ?? 0,
                                             content: .status(0, FastCGI.Constants.FCGI_REQUEST_COMPLETE))
        let promise = channel.writeAndFlush(handler.wrapOutboundOut(endRequestRecord))
        promise.whenComplete { _ in
            guard !self.keepAlive else { return }
            self.channel.close(promise: nil)
        }
    }

    public func rejectMultiplexConnecton(requestId: UInt16) throws {
        fatalError("FastCGI not implemented yet.")
    }

    public func rejectUnsupportedRole() throws {
        fatalError("FastCGI not implemented yet.")
    }

    public func reset() {
    }
}
