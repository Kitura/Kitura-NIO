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
import Dispatch
import NIOOpenSSL
import SSLService
import LoggerAPI
import NIOWebSocket
import CLinuxHelpers

/// An HTTP server that listens for connections on a socket.
public class HTTPServer: Server {

    public typealias ServerType = HTTPServer

    /// HTTP `ServerDelegate`.
    public var delegate: ServerDelegate?

    /// Port number for listening for new connections.
    public private(set) var port: Int?

    private var _state: ServerState = .unknown

    private let syncQ = DispatchQueue(label: "HTTPServer.syncQ")

    /// A server state
    public private(set) var state: ServerState {
        get {
            return self.syncQ.sync {
                return self._state
            }
        }

        set {
            self.syncQ.sync {
                self._state = newValue
            }
        }
    }

    fileprivate let lifecycleListener = ServerLifecycleListener()

    public var keepAliveState: KeepAliveState = .unlimited

    /// The channel used to listen for new connections
    var serverChannel: Channel?

    /// Whether or not this server allows port reuse (default: disallowed)
    public var allowPortReuse = false

    /// Maximum number of pending connections
    private let maxPendingConnections = 100

    /// The event loop group on which the HTTP handler runs
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    private var ctx: ChannelHandlerContext?

    public init() {
#if os(Linux)
        let numberOfCores = Int(linux_sched_getaffinity())
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: numberOfCores > 0 ? numberOfCores : System.coreCount)
#else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
#endif
    }

    /// SSL cert configs for handling client requests
    public var sslConfig: SSLService.Configuration? {
        didSet {
            if let sslConfig = sslConfig {
                //convert to TLSConfiguration
                let config = SSLConfiguration(sslConfig: sslConfig)
                tlsConfig = config.tlsServerConfig()
            }
        }
    }

    /// NIOOpenSSL.TLSConfiguration used with the ServerBootstrap
    private var tlsConfig: TLSConfiguration?

    /// The SSLContext built using the TLSConfiguration
    private var sslContext: NIOOpenSSL.SSLContext?

    /// URI for which the latest WebSocket upgrade was requested by a client
    var latestWebSocketURI: String?

    /// Determines if the request should be upgraded and adds additional upgrade headers to the request
    private func shouldUpgradeToWebSocket(webSocketHandlerFactory: ProtocolHandlerFactory, head: HTTPRequestHead) -> HTTPHeaders? {
        self.latestWebSocketURI = head.uri
        guard webSocketHandlerFactory.isServiceRegistered(at: head.uri) else { return nil }
        var headers = HTTPHeaders()
        if let wsProtocol = head.headers["Sec-WebSocket-Protocol"].first {
            headers.add(name: "Sec-WebSocket-Protocol", value: wsProtocol)
        }
        if let key =  head.headers["Sec-WebSocket-Key"].first {
            headers.add(name: "Sec-WebSocket-Key", value: key)
        }
        return headers
    }

    /// Creates upgrade request and adds WebSocket handler to pipeline
    private func upgradeHandler(webSocketHandlerFactory: ProtocolHandlerFactory, request: HTTPRequestHead) -> EventLoopFuture<Void> {
        guard let ctx = self.ctx else { fatalError("Cannot create ServerRequest") }
        ///TODO: Handle secure upgrade request ("wss://")
        let serverRequest = HTTPServerRequest(ctx: ctx, requestHead: request, enableSSL: false)
        return ctx.channel.pipeline.add(handler: webSocketHandlerFactory.handler(for: serverRequest))
    }

    private typealias ShouldUpgradeFunction = (HTTPRequestHead) -> HTTPHeaders?
    private typealias UpgradePipelineHandlerFunction = (Channel, HTTPRequestHead) -> EventLoopFuture<Void>

    private func generateShouldUpgrade(_ webSocketHandlerFactory: ProtocolHandlerFactory) -> ShouldUpgradeFunction {
        return { (head: HTTPRequestHead) in
            return self.shouldUpgradeToWebSocket(webSocketHandlerFactory: webSocketHandlerFactory, head: head)
        }
    }

    private func generateUpgradePipelineHandler(_ webSocketHandlerFactory: ProtocolHandlerFactory) -> UpgradePipelineHandlerFunction {
        return { (channel: Channel, request: HTTPRequestHead) in
            return self.upgradeHandler(webSocketHandlerFactory: webSocketHandlerFactory, request: request)
        }
    }

    private func createOpenSSLServerHandler() -> OpenSSLServerHandler? {
        if let sslContext = self.sslContext {
            do {
                return try OpenSSLServerHandler(context: sslContext)
            } catch let error {
                Log.error("Failed to create OpenSSLServerHandler. Error: \(error)")
            }
        }
        return nil
    }

    /// Listens for connections on a socket
    ///
    /// - Parameter on: port number for new connections (eg. 8080)
    public func listen(on port: Int) throws {
        self.port = port

        if let tlsConfig = tlsConfig {
            do {
                self.sslContext = try SSLContext(configuration: tlsConfig)
            } catch let error {
                Log.error("Failed to create SSLContext. Error: \(error)")
            }
        }

        var upgraders: [HTTPProtocolUpgrader] = []
        if let webSocketHandlerFactory = ConnectionUpgrader.getProtocolHandlerFactory(for: "websocket") {
            ///TODO: Should `maxFrameSize` be configurable?
            let upgrader = KituraWebSocketUpgrader(maxFrameSize: 1 << 24,
                                                   automaticErrorHandling: false,
                                                   shouldUpgrade: generateShouldUpgrade(webSocketHandlerFactory),
                                                   upgradePipelineHandler: generateUpgradePipelineHandler(webSocketHandlerFactory))
            upgraders.append(upgrader)
        }

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: BacklogOption.OptionType(self.maxPendingConnections))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: allowPortReuse ? 1 : 0)
            .childChannelInitializer { channel in
                let httpHandler = HTTPRequestHandler(for: self)
                let config: HTTPUpgradeConfiguration = (upgraders: upgraders, completionHandler: { ctx in
                    self.ctx = ctx
                    _ = channel.pipeline.remove(handler: httpHandler)
                })
                return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config, withErrorHandling: true).then {
                    if let openSSLServerHandler = self.createOpenSSLServerHandler() {
                        _ = channel.pipeline.add(handler: openSSLServerHandler, first: true)
                    }
                    return channel.pipeline.add(handler: httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)

        do {
            serverChannel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
            self.port = serverChannel?.localAddress?.port.map { Int($0) }
            self.state = .started
            self.lifecycleListener.performStartCallbacks()
        } catch let error {
            self.state = .failed
            self.lifecycleListener.performFailCallbacks(with: error)
            Log.error("Error trying to bind to \(port): \(error)")
            throw error
        }

        Log.info("Listening on port \(self.port!)")
        Log.verbose("Options for port \(self.port!): maxPendingConnections: \(maxPendingConnections), allowPortReuse: \(self.allowPortReuse)")

        let queuedBlock = DispatchWorkItem(block: {
            guard let serverChannel = self.serverChannel else { return }
            try! serverChannel.closeFuture.wait()
            self.state = .stopped
            self.lifecycleListener.performStopCallbacks()
        })
        ListenerGroup.enqueueAsynchronously(on: DispatchQueue.global(), block: queuedBlock)
    }

    /// Static method to create a new HTTPServer and have it listen for connections.
    ///
    /// - Parameter on: port number for accepting new connections
    /// - Parameter delegate: the delegate handler for HTTP connections
    ///
    /// - Returns: a new `HTTPServer` instance
    public static func listen(on port: Int, delegate: ServerDelegate?) throws -> ServerType {
        let server = HTTP.createServer()
        server.delegate = delegate
        try server.listen(on: port)
        return server
    }

    /// Listens for connections on a socket
    ///
    /// - Parameter port: port number for new connections (eg. 8080)
    /// - Parameter errorHandler: optional callback for error handling
    @available(*, deprecated, message: "use 'listen(on:) throws' with 'server.failed(callback:)' instead")
    public func listen(port: Int, errorHandler: ((Swift.Error) -> Void)?) {
        do {
            try listen(on: port)
        } catch let error {
            if let callback = errorHandler {
                callback(error)
            } else {
                Log.error("Error listening on port \(port): \(error)")
            }
        }
    }

    /// Static method to create a new HTTPServer and have it listen for connections.
    ///
    /// - Parameter port: port number for accepting new connections
    /// - Parameter delegate: the delegate handler for HTTP connections
    /// - Parameter errorHandler: optional callback for error handling
    ///
    /// - Returns: a new `HTTPServer` instance
    @available(*, deprecated, message: "use 'listen(on:delegate:) throws' with 'server.failed(callback:)' instead")
    public static func listen(port: Int, delegate: ServerDelegate, errorHandler: ((Swift.Error) -> Void)?) -> ServerType {
        let server = HTTP.createServer()
        server.delegate = delegate
        server.listen(port: port, errorHandler: errorHandler)
        return server
    }

    deinit {
        do {
            try eventLoopGroup.syncShutdownGracefully()
        } catch {
            Log.error("Failed to shutdown eventLoopGroup")
        }
    }

    /// Stop listening for new connections.
    public func stop() {
        guard let serverChannel = serverChannel else { return }
        do {
            try serverChannel.close().wait()
        } catch let error {
            Log.error("Failed to close the server channel. Error: \(error)")
        }
        self.state = .stopped
    }

    /// Add a new listener for server beeing started
    ///
    /// - Parameter callback: The listener callback that will run on server successfull start-up
    ///
    /// - Returns: a `HTTPServer` instance
    @discardableResult
    public func started(callback: @escaping () -> Void) -> Self {
        self.lifecycleListener.addStartCallback(perform: self.state == .started, callback)
        return self
    }

    /// Add a new listener for server beeing stopped
    ///
    /// - Parameter callback: The listener callback that will run when server stops
    ///
    /// - Returns: a `HTTPServer` instance
    @discardableResult
    public func stopped(callback: @escaping () -> Void) -> Self {
        self.lifecycleListener.addStopCallback(perform: self.state == .stopped, callback)
        return self
    }

    /// Add a new listener for server throwing an error
    ///
    /// - Parameter callback: The listener callback that will run when server throws an error
    ///
    /// - Returns: a `HTTPServer` instance
    @discardableResult
    public func failed(callback: @escaping (Swift.Error) -> Void) -> Self {
        self.lifecycleListener.addFailCallback(callback)
        return self
    }

    /// Add a new listener for when listenSocket.acceptClientConnection throws an error
    ///
    /// - Parameter callback: The listener callback that will run
    ///
    /// - Returns: a Server instance
    @discardableResult
    public func clientConnectionFailed(callback: @escaping (Swift.Error) -> Void) -> Self {
        self.lifecycleListener.addClientConnectionFailCallback(callback)
        return self
    }
}

class HTTPDummyServerDelegate: ServerDelegate {
    /// Handle new incoming requests to the server
    ///
    /// - Parameter request: The ServerRequest class instance for working with this request.
    ///                     The ServerRequest object enables you to get the query parameters, headers, and body amongst other
    ///                     information about the incoming request.
    /// - Parameter response: The ServerResponse class instance for working with this request.
    ///                     The ServerResponse object enables you to build and send your response to the client who sent
    ///                     the request. This includes headers, the body, and the response code.
    func handle(request: ServerRequest, response: ServerResponse) {
        do {
            response.statusCode = .notFound
            let theBody = "Path not found"
            response.headers["Content-Type"] = ["text/plain"]
            response.headers["Content-Length"] = [String(theBody.utf8.count)]
            try response.write(from: theBody)
            try response.end()
        } catch {
            Log.error("Failed to send the response. Error = \(error)")
        }
    }
}

// A specialized Websocket upgrader for Kitura.

// A WebSocket upgrade request is accompanied with two mandatory headers - `Sec-WebSocket-Version` and `Sec-WebSocket-Key`.
// An upgrade fails if either of these headers are absent or if they have multiple values.
// An upgrade also fails if the `Sec-WebSocket-Version` value is not set to 13.
// This means we have at least three kinds of errors related to invalid upgrade headers. However, the `NIOWebSocket.NIOWebSocketUpgradeError`
// type does not have cases that indicate all these three types of errors. There's only a general `invalidUpgradeHeader` case.
// A WebSocket server that catches this error has no way to inform the client about what exactly went wrong.
//
// Issue created with swift-nio: https://github.com/apple/swift-nio/issues/577
//
// A work-around suggested in the issue is to create a wrapper-upgrader around the existing upgrader and generate the more granular errors therein.
// This work-around will have to be removed once the limitation is removed from swift-nio, possibly in version 2.0

// TODO: Re-evaluate the need for this class when swift-nio 2.0 is released.
final class KituraWebSocketUpgrader: HTTPProtocolUpgrader {
    private let _wrappedUpgrader: WebSocketUpgrader

    public init(maxFrameSize: Int, automaticErrorHandling: Bool = true, shouldUpgrade: @escaping (HTTPRequestHead) -> HTTPHeaders?,
                upgradePipelineHandler: @escaping (Channel, HTTPRequestHead) -> EventLoopFuture<Void>) {
        _wrappedUpgrader = WebSocketUpgrader(maxFrameSize: maxFrameSize, automaticErrorHandling: automaticErrorHandling, shouldUpgrade: shouldUpgrade,
                                             upgradePipelineHandler: upgradePipelineHandler)
    }

    public convenience init(automaticErrorHandling: Bool = true, shouldUpgrade: @escaping (HTTPRequestHead) -> HTTPHeaders?,
                upgradePipelineHandler: @escaping (Channel, HTTPRequestHead) -> EventLoopFuture<Void>) {
        self.init(maxFrameSize: 1 << 14, automaticErrorHandling: automaticErrorHandling,
                  shouldUpgrade: shouldUpgrade, upgradePipelineHandler: upgradePipelineHandler)
    }

    public var supportedProtocol: String {
        return self._wrappedUpgrader.supportedProtocol
    }

    public var requiredUpgradeHeaders: [String] {
        return _wrappedUpgrader.requiredUpgradeHeaders
    }

    public func buildUpgradeResponse(upgradeRequest: HTTPRequestHead, initialResponseHeaders: HTTPHeaders) throws -> HTTPHeaders {
        do {
            return try _wrappedUpgrader.buildUpgradeResponse(upgradeRequest: upgradeRequest, initialResponseHeaders: initialResponseHeaders)
        } catch {
            if case NIOWebSocketUpgradeError.invalidUpgradeHeader = error {
                let keyHeader = upgradeRequest.headers[canonicalForm: "Sec-WebSocket-Key"]
                let versionHeader = upgradeRequest.headers[canonicalForm: "Sec-WebSocket-Version"]

                if keyHeader.count == 0 {
                    throw KituraWebSocketUpgradeError.noWebSocketKeyHeader
                } else if keyHeader.count > 1 {
                    throw KituraWebSocketUpgradeError.invalidKeyHeaderCount(keyHeader.count)
                } else if versionHeader.count == 0 {
                    throw KituraWebSocketUpgradeError.noWebSocketVersionHeader
                } else if versionHeader.count > 1 {
                    throw KituraWebSocketUpgradeError.invalidVersionHeaderCount(versionHeader.count)
                } else if versionHeader.first! != "13" {
                    throw KituraWebSocketUpgradeError.invalidVersionHeader(versionHeader.first!)
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    public func upgrade(ctx: ChannelHandlerContext, upgradeRequest: HTTPRequestHead) -> EventLoopFuture<Void> {
        return _wrappedUpgrader.upgrade(ctx: ctx, upgradeRequest: upgradeRequest)
    }
}

// Detailed WebSocket upgrade errors
// TODO: Re-evaluate the need for this enum after swift-nio 2.0 is released.
enum KituraWebSocketUpgradeError: Error {
    // The upgrade request had no Sec-WebSocket-Key header
    case noWebSocketKeyHeader

    // The upgrade request had no Sec-WebSocket-Version header
    case noWebSocketVersionHeader

    // The upgrade request had multiple Sec-WebSocket-Key header values
    case invalidKeyHeaderCount(Int)

    // The upgrade request had multiple Sec-WebSocket-Version header values
    case invalidVersionHeaderCount(Int)

    // The Sec-WebSocket-Version is not 13
    case invalidVersionHeader(String)
}
