import NIO
import Foundation

public protocol FastCGIConnectorProtocol {
    init(url: String)

    func send(request: HTTPServerRequest,
              keepAlive: Bool,
              responseHandler: @escaping (HTTPResponseParts) -> Void) throws
    func close()
}

public typealias HTTPResponseParts = (headers: [String: String], status: Int, body: Data?)

public class FastCGIConnector: FastCGIConnectorProtocol {

    private var url: String
    private var hostname: String? = nil
    private var port: Int? = nil
    private var channel: Channel? = nil
    private var responseReceived = DispatchSemaphore(value: 0)
    
    required public init (url: String) {
        self.url = url
        if let url = URL(string: url) {
            self.hostname = url.host
            self.port = url.port
        }
    }
    
    public func send(request: HTTPServerRequest,
                     keepAlive: Bool,
                     responseHandler: @escaping (HTTPResponseParts) -> Void) throws {
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandler(FastCGIRecordEncoderHandler<FastCGIRecordEncoder>()).flatMap { _ in channel.pipeline.addHandler(RequestTranslator())
                }.flatMap { _ in channel.pipeline.addHandler(FastCGIRecordDecoderHandler<FastCGIRecordDecoder>())
                }.flatMap { _ in
                    channel.pipeline.addHandler(ResponseTranslator())
                }.flatMap { _ in
                    channel.pipeline.addHandler(FastCGIProxyHandler(responseHandler: responseHandler))
                }
        }
        guard let host = self.hostname, let port = self.port else { return } //TODO: throw an error
        self.channel = try! bootstrap.connect(host: host, port: port).wait()
        try! self.channel?.writeAndFlush(request).wait()
        responseReceived.wait()
        
        if keepAlive {
            self.channel?.close(promise: nil)
        }
    }
    public func close() {
        self.channel?.close(promise: nil)
        }

    deinit {
        self.channel?.close(promise: nil)
        }
    }

class FastCGIProxyHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPResponseParts

    let responseHandler: (HTTPResponseParts) -> Void

    init(responseHandler: @escaping (HTTPResponseParts) -> Void) {
        self.responseHandler = responseHandler
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let responseParts = self.unwrapInboundIn(data)
        responseHandler(responseParts)
    }
}
