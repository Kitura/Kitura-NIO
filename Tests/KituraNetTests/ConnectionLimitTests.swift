import Foundation
import Dispatch
import NIO
import XCTest
import KituraNet

class ConnectionLimitTests: KituraNetTest {
    static var allTests: [(String, (ConnectionLimitTests) -> () throws -> Void)] {
        return [
            ("testConnectionLimit", testConnectionLimit),
        ]
    }
    
    override func setUp() {
        doSetUp()
    }

    override func tearDown() {
        doTearDown()
    }
    func testConnectionLimit () {
        performServerTest(serverConfig: HTTPServerConfiguration(requestSizeLimit: 10000, connectionLimit: 100), nil, useSSL: false, asyncTasks: { expectation in
            var channel: Channel
            let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let bootstrap = ClientBootstrap(group: group)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHTTPClientHandlers().flatMap {_ in
                            channel.pipeline.addHandler(HTTPResponseHandler())
                        }
                    }
            channel = bootstrap.connect(host: "localhost", port: 8080) as! Channel
            })
    }
}
