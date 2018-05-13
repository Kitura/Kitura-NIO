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

/// An HTTP server that listens for connections on a socket.
public class HTTPServer : Server {
    
    public typealias ServerType = HTTPServer

    /// HTTP `ServerDelegate`.
    public var delegate: ServerDelegate?

    /// Port number for listening for new connections.
    public private(set) var port: Int?

    /// A server state.
    public private(set) var state: ServerState = .unknown

    fileprivate let lifecycleListener = ServerLifecycleListener()

    public var keepAliveState: KeepAliveState = .unlimited

    public var supportIPv6 = false

    /// The channel used to listen for new connections (IPv4)
    var serverChannelIPv4: Channel!

    /// The channel used to listen for new connections (IPv6)
    var serverChannelIPv6: Channel!

    /// Whether or not this server allows port reuse (default: disallowed)
    public var allowPortReuse = false

    /// Maximum number of pending connections
    private let maxPendingConnections = 100

    /// The event loop group on which the HTTP handler runs
    let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: System.coreCount)

    public init() { }

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
    private var sslContext: SSLContext?


    /// Listens for connections on a socket
    ///
    /// - Parameter on: port number for new connections (eg. 8080)
    public func listen(on port: Int) throws {
        self.port = port

        if let tlsConfig = tlsConfig {
            self.sslContext = try! SSLContext(configuration: tlsConfig)
        }

        if self.delegate == nil {
            self.delegate = HTTPDummyServerDelegate()
        }

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: BacklogOption.OptionType(self.maxPendingConnections))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: allowPortReuse ? 1 : 0)
            .childChannelInitializer { channel in
                channel.pipeline.add(handler: IdleStateHandler(allTimeout: TimeAmount.seconds(Int(HTTPHandler.keepAliveTimeout)))).then {
                    channel.pipeline.configureHTTPServerPipeline().then {
                        if let sslContext = self.sslContext {
                            _ = channel.pipeline.add(handler: try! OpenSSLServerHandler(context: sslContext), first: true)
                        }
                        return channel.pipeline.add(handler: HTTPHandler(for: self))
                    }
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)


        do {
            //To support both IPv4 and IPv6
            serverChannelIPv4 = try bootstrap.bind(host: "127.0.0.1", port: port).wait()
            self.port = serverChannelIPv4?.localAddress?.port.map { Int($0) }
            if supportIPv6 {
                serverChannelIPv6 = try bootstrap.bind(host: "::1", port: port).wait()
                //TODO: update the IPv6 port number
            }
            self.state = .started
            self.lifecycleListener.performStartCallbacks()
        } catch let error {
            self.state = .failed
            self.lifecycleListener.performFailCallbacks(with: error)
            Log.error("Error trying to bing to \(port): \(error)")
            throw error
        }

        Log.info("Listening on port \(self.port!)")
        Log.verbose("Options for port \(self.port!): maxPendingConnections: \(maxPendingConnections), allowPortReuse: \(self.allowPortReuse)")

        let queuedBlock = DispatchWorkItem(block: { 
            try! self.serverChannelIPv4.closeFuture.wait()
            if self.supportIPv6 {
                try! self.serverChannelIPv6.closeFuture.wait()
            }
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
        try! eventLoopGroup.syncShutdownGracefully()
    }

    /// Stop listening for new connections.
    public func stop() {
        guard serverChannelIPv4 != nil else { return }
        try! serverChannelIPv4.close().wait()
        if supportIPv6 {
            try! serverChannelIPv6.close().wait()
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

private class HTTPDummyServerDelegate: ServerDelegate {
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
            response.headers["Content-Length"] = [String(theBody.lengthOfBytes(using: .utf8))]
            try response.write(from: theBody)
            try response.end()
        }
        catch {
            Log.error("Failed to send the response. Error = \(error)")
        }
    } 
}
