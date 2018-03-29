import NIO
import NIOHTTP1
import Dispatch

public class HTTPServer : Server {
    
    public typealias ServerType = HTTPServer

    public var delegate: ServerDelegate?

    public private(set) var port: Int?

    public private(set) var state: ServerState = .unknown

    public var allowPortReuse = false

    let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: System.coreCount)

    public func listen(on port: Int) throws {
        self.port = port
        //TODO: Add a dummy delegate
        guard let delegate = self.delegate else { fatalError("No delegate registered") }
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 100)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: allowPortReuse ? 1 : 0)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().then {
                    channel.pipeline.add(handler: HTTPHandler(delegate: delegate))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        let serverChannel = try! bootstrap.bind(host: "localhost", port: port)  //TODO: localhost?
            .wait()
        let queuedBlock = DispatchWorkItem(block: { try! serverChannel.closeFuture.wait() })
        ListenerGroup.enqueueAsynchronously(on: DispatchQueue.global(), block: queuedBlock)
    }

    public static func listen(on port: Int, delegate: ServerDelegate?) throws -> ServerType {
        let server = HTTP.createServer()
        server.delegate = delegate
        try server.listen(on: port)
        return server
    }

    @available(*, deprecated, message: "use 'listen(on:) throws' with 'server.failed(callback:)' instead")
    public func listen(port: Int, errorHandler: ((Swift.Error) -> Void)?) {
        do {
            try listen(on: port)
        } catch let error {
            if let callback = errorHandler {
                callback(error)
            } else {
                //Log.error("Error listening on port \(port): \(error)")
            }
        }
    }

    @available(*, deprecated, message: "use 'listen(on:delegate:) throws' with 'server.failed(callback:)' instead")
    public static func listen(port: Int, delegate: ServerDelegate, errorHandler: ((Swift.Error) -> Void)?) -> ServerType {
        let server = HTTP.createServer()
        server.delegate = delegate
        server.listen(port: port, errorHandler: errorHandler)
        return server
    }

    public func stop() {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    @discardableResult
    public func started(callback: @escaping () -> Void) -> Self {
        //TODO
        return self
    }

    @discardableResult
    public func stopped(callback: @escaping () -> Void) -> Self {
        //TODO
        return self
    }

    @discardableResult
    public func failed(callback: @escaping (Swift.Error) -> Void) -> Self {
        //TODO
        return self
    }

    @discardableResult
    public func clientConnectionFailed(callback: @escaping (Swift.Error) -> Void) -> Self {
        //TODO
        return self
    }
}
