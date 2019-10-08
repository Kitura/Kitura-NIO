import Foundation
import Dispatch
import NIO
import XCTest
import KituraNet
import NIOHTTP1
import NIOWebSocket
import LoggerAPI

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
    
    func establishConnection(expectation: XCTestExpectation, responseHandler: HTTPResponseHandler) {
        var channel: Channel
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {_ in
                    channel.pipeline.addHandler(responseHandler)
                }
        }
        do {
            try channel = bootstrap.connect(host: "localhost", port: self.port).wait()
            let request = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1), method: .GET, uri: "/")
            self.sendRequest(request: request, on: channel)
        } catch _ {
            XCTFail("Connection is not established.")
        }
    }

    func testConnectionLimit() {
        let delegate = TestConnectionLimitDelegate()
        performServerTest(serverConfig: ServerOptions(requestSizeLimit: 10000, connectionLimit: 1), delegate, socketType: .tcp, useSSL: false, asyncTasks: { expectation in
        let payload = "Hello, World!"
        var payloadBuffer = ByteBufferAllocator().buffer(capacity: 1024)
        payloadBuffer.writeString(payload)
        _ = self.establishConnection(expectation: expectation, responseHandler: HTTPResponseHandler(expectedStatus:HTTPResponseStatus.ok, expectation: expectation))
    }, { expectation in
        let payload = "Hello, World!"
        var payloadBuffer = ByteBufferAllocator().buffer(capacity: 1024)
        payloadBuffer.writeString(payload)
        _ =  self.establishConnection(expectation: expectation, responseHandler: HTTPResponseHandler(expectedStatus:HTTPResponseStatus.serviceUnavailable, expectation: expectation))
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

class HTTPResponseHandler: ChannelInboundHandler {
    let expectedStatus: HTTPResponseStatus
    let expectation: XCTestExpectation
    init(expectedStatus: HTTPResponseStatus, expectation: XCTestExpectation) {
        self.expectedStatus = expectedStatus
        self.expectation = expectation
    }
    typealias InboundIn = HTTPClientResponsePart
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let header):
            let status = header.status
            XCTAssertEqual(status, expectedStatus)
            expectation.fulfill()
        default: do {
            }
        }
    }
}
