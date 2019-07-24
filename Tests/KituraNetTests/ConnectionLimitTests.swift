import Foundation
import Dispatch
import NIO
import XCTest
import KituraNet
import NIOHTTP1

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
    private func sendRequest(request: HTTPRequestHead, on channel: Channel) {
        channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        try! channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil))).wait()
    }
    
    func testConnectionLimit () {
        let delegate = TestConnectionLimitDelegate()
        performServerTest(serverConfig: HTTPServerConfiguration(requestSizeLimit: 10000, connectionLimit: 1), delegate, socketType: .tcp, useSSL: false, asyncTasks: { expectation in
            //print("port is:",self.port)
            var channel: Channel
            var channel1: Channel
            let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let bootstrap = ClientBootstrap(group: group)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHTTPClientHandlers().flatMap {_ in
                            channel.pipeline.addHandler(HTTPResponseHandler())
                        }
            }
            do {
                print("check connecting to \(self.port)")
                try channel = bootstrap.connect(host: "localhost", port: self.port).wait()
                let request = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1), method: .GET, uri: "/")
                self.sendRequest(request: request, on: channel)
            } catch (let e) {
                print("error: ",e)
                XCTFail("Connection is not established.")
            }
            do {
                try channel1 = bootstrap.connect(host: "localhost", port: self.port).wait()
                print("connecting to channel1")
            } catch {
                
            }
            //expectation.fulfill()
            })
    }
}
class TestConnectionLimitDelegate: ServerDelegate {
    
    func handle(request: ServerRequest, response: ServerResponse) {
        do {
            let result: String = "Hello, World!"
            response.statusCode = .OK
            response.headers["Content-Type"] = ["text/plain"]
            response.headers["Content-Length"] = ["\(result.count)"]
            try response.end(text: result)
        } catch {
            XCTFail("Error while writing response")
        }
    }
}
