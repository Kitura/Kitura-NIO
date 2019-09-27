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
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch

internal class HTTPRequestHandler: ChannelInboundHandler, RemovableChannelHandler {

    /// The HTTPServer instance on which this handler is installed
    var server: HTTPServer

    var requestSize: Int = 0

    /// The serverRequest related to this handler instance
    var serverRequest: HTTPServerRequest?

    /// The serverResponse related to this handler instance
    var serverResponse: HTTPServerResponse?

    /// We'd want to send an error response only once
    var errorResponseSent = false

    var keepAliveState: KeepAliveState {
        set {
            self.syncQueue.sync {
                _keepAliveState = newValue
            }
        }

        get {
            return self.syncQueue.sync {
                return _keepAliveState
            }
        }
    }

    private let syncQueue = DispatchQueue(label: "HTTPServer.keepAliveSync")

    private var _keepAliveState: KeepAliveState = .unlimited

    static let keepAliveTimeout: TimeInterval = 60

    private(set) var clientRequestedKeepAlive = false

    private(set) var enableSSLVerification = false

    public init(for server: HTTPServer) {
        self.server = server
        self.keepAliveState = server.keepAliveState
        if server.sslConfig != nil {
            self.enableSSLVerification = true
        }
    }
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        // If an error response was already sent, we'd want to spare running through this for now.
        // If an upgrade to WebSocket fails, both `errorCaught` and `channelRead` are triggered.
        // We'd want to return the error via `errorCaught`.
        if errorResponseSent { return }
        switch request {
        case .head(let header):
            serverRequest = HTTPServerRequest(channel: context.channel, requestHead: header, enableSSL: enableSSLVerification)
            if let requestSizeLimit = server.options.requestSizeLimit,
                let contentLength = header.headers["Content-Length"].first,
                let contentLengthValue = Int(contentLength) {
                if contentLengthValue > requestSizeLimit {
                    do {
                        if let (httpStatus, response) = server.options.requestSizeResponseGenerator(requestSizeLimit, serverRequest?.remoteAddress ?? "") {
                            serverResponse = HTTPServerResponse(channel: context.channel, handler: self)
                            errorResponseSent = true
                            try serverResponse?.end(with: httpStatus, message: response)
                        }
                    } catch {
                        Log.error("Failed to send error response")
                    }
                    context.close()
                }
            }
            serverRequest = HTTPServerRequest(channel: context.channel, requestHead: header, enableSSL: enableSSLVerification)
            self.clientRequestedKeepAlive = header.isKeepAlive
        case .body(var buffer):
            requestSize += buffer.readableBytes
            if let requestSizeLimit = server.options.requestSizeLimit {
                if requestSize > requestSizeLimit {
                    do {
                        if let (httpStatus, response) = server.options.requestSizeResponseGenerator(requestSizeLimit,serverRequest?.remoteAddress ?? "") {
                            serverResponse = HTTPServerResponse(channel: context.channel, handler: self)
                            errorResponseSent = true
                            try serverResponse?.end(with: httpStatus, message: response)
                        }
                    } catch {
                        Log.error("Failed to send error response")
                    }
                }
            }
            guard let serverRequest = serverRequest else {
                Log.error("No ServerRequest available")
                return
            }
            if serverRequest.buffer == nil {
                serverRequest.buffer = BufferList(with: buffer)
            } else {
                serverRequest.buffer!.byteBuffer.writeBuffer(&buffer)
            }

        case .end:
            requestSize = 0
            server.connectionCount.add(1)
            if let connectionLimit = server.options.connectionLimit {
                if server.connectionCount.load() > connectionLimit {
                    do {
                        if let (httpStatus, response) = server.options.connectionResponseGenerator(connectionLimit,serverRequest?.remoteAddress ?? "") {
                            serverResponse = HTTPServerResponse(channel: context.channel, handler: self)
                            errorResponseSent = true
                            try serverResponse?.end(with: httpStatus, message: response)
                        }
                    } catch {
                        Log.error("Failed to send error response")
                    }
                }
            }
            serverResponse = HTTPServerResponse(channel: context.channel, handler: self)
            //Make sure we use the latest delegate registered with the server
            DispatchQueue.global().async {
                guard let serverRequest = self.serverRequest, let serverResponse = self.serverResponse else { return }
                let delegate = self.server.delegate ?? HTTPDummyServerDelegate()
                Monitor.delegate?.started(request: serverRequest, response: serverResponse)
                delegate.handle(request: serverRequest, response: serverResponse)
            }
        }
    }

    //IdleStateEvents are received on this method
    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if event is IdleStateHandler.IdleStateEvent {
            _ = context.close()
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        guard !errorResponseSent else { return }
        var message: String?
        switch error {
        case KituraWebSocketUpgradeError.noWebSocketKeyHeader:
            message = "Sec-WebSocket-Key header missing in the upgrade request"
        case KituraWebSocketUpgradeError.noWebSocketVersionHeader:
            message = "Sec-WebSocket-Version header missing in the upgrade request"
        case KituraWebSocketUpgradeError.invalidKeyHeaderCount(_):
            break
        case KituraWebSocketUpgradeError.invalidVersionHeaderCount(_):
            break
        case KituraWebSocketUpgradeError.invalidVersionHeader(_):
            message = "Only WebSocket protocol version 13 is supported"
        default:
            // Handle only NIOWebSocketUpgradeError here, nothing else
            if let upgradeError = error as? NIOWebSocketUpgradeError, upgradeError == .unsupportedWebSocketTarget {
                let target = server.latestWebSocketURI
                message = "No service has been registered for the path \(target)"
            } else {
                context.close(promise: nil)
                return
            }
        }

        do {
            serverResponse = HTTPServerResponse(channel: context.channel, handler: self)
            errorResponseSent = true
            try serverResponse?.end(with: .badRequest, message: message)
        } catch {
            Log.error("Failed to send error response")
        }

    }

    func updateKeepAliveState() {
        keepAliveState.decrement()
    }

    func channelInactive(context: ChannelHandlerContext, httpServer: HTTPServer) {
        httpServer.connectionCount.sub(1)
    }
}
