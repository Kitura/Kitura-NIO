import Foundation
import Dispatch
import NIO
import XCTest
import KituraNet
import NIOHTTP1
import NIOWebSocket
import LoggerAPI

class RequestSizeTests: KituraNetTest {
    static var allTests: [(String, (RequestSizeTests) -> () throws -> Void)] {
        return [
            ("testRequestSize", testRequestSize),
            ("testConnectionLimit",testConnectionLimit),
        ]
    }
    
    override func setUp() {
        doSetUp()
    }
    
    override func tearDown() {
        doTearDown()
    }
    private func sendRequest(request:HTTPRequestHead, on channel: Channel, payload: ByteBuffer) {
        channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        channel.write(NIOAny(HTTPClientRequestPart.body(.byteBuffer(payload))), promise: nil)
        channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil)), promise: nil)
    }

    func establishConnection(expectation: XCTestExpectation, responseHandler: HTTPConfigTestsResponseHandler, payload: ByteBuffer) -> Channel {
        var channel: Channel? = nil
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                 return channel.pipeline.addHTTPClientHandlers().flatMap {_ in
                    channel.pipeline.addHandler(responseHandler, position: .first)
                }
        }
        do {
            try channel = bootstrap.connect(host: "localhost", port: self.port).wait()
            let request = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1), method: .POST, uri: "/")
            self.sendRequest(request: request, on: channel!, payload: payload )
        } catch {
            XCTFail("Connection is not established.")
        }
        return channel!
    }
    
    func testRequestSize () {
        performServerTest(serverConfig: HTTPServerConfiguration(requestSizeLimit: 10000, connectionLimit: 1), nil, socketType: .tcp, useSSL: false, asyncTasks: { expectation in
            let payload = "[" + contentTypesString + "]"
            var payloadBuffer = ByteBufferAllocator().buffer(capacity: 10000)
            payloadBuffer.writeString(payload)
            _ = self.establishConnection(expectation: expectation, responseHandler: HTTPConfigTestsResponseHandler(expectation: expectation, expectedSubstring:HTTP.statusCodes[HTTPStatusCode.requestTooLong.rawValue] ?? ""), payload: payloadBuffer)
        })
    }
    func testConnectionLimit() {
        let delegate = TestConnectionLimitDelegate()
        performServerTest(serverConfig: HTTPServerConfiguration(requestSizeLimit: 10000, connectionLimit: 1), delegate, socketType: .tcp, useSSL: false, asyncTasks: { expectation in
            let payload = "Hello, World!"
            var payloadBuffer = ByteBufferAllocator().buffer(capacity: 1024)
            payloadBuffer.writeString(payload)
             _ = self.establishConnection(expectation: expectation, responseHandler: HTTPConfigTestsResponseHandler(expectation: expectation, expectedSubstring:"HTTP/1.1 200 OK"), payload: payloadBuffer)
        }, { expectation in
            let payload = "Hello, World!"
            var payloadBuffer = ByteBufferAllocator().buffer(capacity: 1024)
            payloadBuffer.writeString(payload)
             _ =  self.establishConnection(expectation: expectation, responseHandler: HTTPConfigTestsResponseHandler(expectation: expectation, expectedSubstring: HTTP.statusCodes[HTTPStatusCode.serviceUnavailable.rawValue] ?? ""), payload: payloadBuffer)
        })
    }
}
class TestConnectionLimitDelegate: ServerDelegate {
    func handle(request: ServerRequest, response: ServerResponse) {
        do {
            try response.end()
        } catch {
            XCTFail("Error while writing response")
        }
    }
}
