import NIO
import NIOHTTP1
import Dispatch

public class HTTPServer : Server {
    
    public typealias ServerType = HTTPServer

    public var delegate: ServerDelegate? {
        didSet {
            httpHandler.delegate = delegate
       }
    }

    private var httpHandler: HTTPHandler = HTTPHandler()

    public private(set) var port: Int?

    public var keepAliveState: KeepAliveState = .unlimited

    public private(set) var state: ServerState = .unknown

    fileprivate let lifecycleListener = ServerLifecycleListener()

    var serverChannel: Channel!

    public var allowPortReuse = false

    let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: System.coreCount)

    public func listen(on port: Int) throws {
        self.port = port
        //TODO: Add a dummy delegate
        guard let delegate = self.delegate else { fatalError("No delegate registered") }
        httpHandler.delegate = delegate
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 100)
            //TODO: always setting to SO_REUSEADDR for now
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().then {
                    channel.pipeline.add(handler: self.httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)


        do {
            serverChannel = try bootstrap.bind(host: "127.0.0.1", port: port)  //TODO: localhost?
                .wait()
            self.state = .started
            self.lifecycleListener.performStartCallbacks()
        } catch let error {
            self.state = .failed
            self.lifecycleListener.performFailCallbacks(with: error)
            throw error
        }

        let queuedBlock = DispatchWorkItem(block: { 
            try! self.serverChannel.closeFuture.wait()
            self.state = .stopped
            self.lifecycleListener.performStopCallbacks()
        })
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
    
    deinit { 
        try! eventLoopGroup.syncShutdownGracefully()
    }

    public func stop() {
        guard serverChannel != nil else { return }
        try! serverChannel.close().wait()
        self.state = .stopped
    }

    @discardableResult
    public func started(callback: @escaping () -> Void) -> Self {
        self.lifecycleListener.addStartCallback(perform: self.state == .started, callback)
        return self
    }

    @discardableResult
    public func stopped(callback: @escaping () -> Void) -> Self {
        self.lifecycleListener.addStopCallback(perform: self.state == .stopped, callback)
        return self
    }

    @discardableResult
    public func failed(callback: @escaping (Swift.Error) -> Void) -> Self {
        self.lifecycleListener.addFailCallback(callback) 
        return self
    }

    @discardableResult
    public func clientConnectionFailed(callback: @escaping (Swift.Error) -> Void) -> Self {
        self.lifecycleListener.addClientConnectionFailCallback(callback)
        return self
    }
}
