import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch

#if os(Linux)
    let numberOfCores = Int(linux_sched_getaffinity())
    fileprivate let globalELG = MultiThreadedEventLoopGroup(numberOfThreads: numberOfCores > 0 ? numberOfCores : System.coreCount)
#else
    fileprivate let globalELG = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
#endif



protocol FCGIConnectorProtocol {
    
    init(URL: String, keepAlive: Bool)
   
    func send( request: HTTPServerRequest, responseHandler: @escaping (HTTPResponseParts) -> Void)
}
public typealias HTTPResponseParts = (headers: [String: String], status: Int, body: Data?)

public class FCGIConnector: FCGIConnectorProtocol {
    var keepAlive: Bool
    var bootstrap: ClientBootstrap?
    var channel: Channel?
    var responseReceived = DispatchSemaphore(value: 0)
    var port: Int?
    
    public private(set) var url: String = ""

    private var percentEncodedURL: String = ""
    
    required init(URL: String, keepAlive: Bool = false) {
        self.url = URL
        self.keepAlive = keepAlive
    }
    
    private func initializeClientBootstrap(eventLoopGroup: EventLoopGroup) {
        bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(RequestTranslator()).flatMap {_ in
                    channel.pipeline.addHandler(FastCGIRecordEncoderHandler<FastCGIRecordEncoder>())
                }
            }
    }
    
    func send(request: HTTPServerRequest, responseHandler: @escaping (HTTPResponseParts) -> Void) {
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        initializeClientBootstrap(eventLoopGroup: group)
        let hostName = URL(string: percentEncodedURL)?.host ?? "" //TODO: what could be the failure path here
        let portNumber = self.port
        do {
            guard let bootstrap = bootstrap else { return }
            channel = try! bootstrap.connect(host: hostName, port: Int(self.port!)).wait() as Channel
            try! self.channel?.writeAndFlush(request).wait()
            responseReceived.wait()
            if (keepAlive == false) {
                self.channel?.close(promise: nil)
            }
        }
    }
}
    
