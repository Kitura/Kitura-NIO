import NIO
import NIOHTTP1
import XCTest
import KituraNet


class ChannelQuiescingTests: KituraNetTest {

    static var allTests: [(String, (ChannelQuiescingTests) -> () throws -> Void)] {
        return [
            ("testChannelQuiescing", testChannelQuiescing),
        ]
    }

    func testChannelQuiescing() {
        let server = HTTP.createServer()
        try! server.listen(on: 0)
        let port = server.port ?? -1
        server.delegate = SleepingDelegate()

        let connectionClosedExpectation = expectation(description: "Server closes connections")
        let bootstrap = ClientBootstrap(group: MultiThreadedEventLoopGroup(numberOfThreads: 1))
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(connectionClosedExpectation))
                }
        }
        let request = HTTPRequestHead(version: HTTPVersion.init(major: 1, minor: 1), method: .GET, uri: "/")

        // Make the first connection
        let channel1 = try! bootstrap.connect(host: "localhost", port: port).wait()
        _ = channel1.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        try! channel1.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil))).wait()

        // Make the second connection
        let channel2 = try! bootstrap.connect(host: "localhost", port: port).wait()
        _ = channel2.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        try! channel2.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil))).wait()

        // The server must close both the connections
        connectionClosedExpectation.expectedFulfillmentCount = 2

        // Give time for the route handlers to kick in
        sleep(1)

        // Stop the server
        server.stop()
        waitForExpectations(timeout: 10)
    }
}

class SleepingDelegate: ServerDelegate {
    public func handle(request: ServerRequest, response: ServerResponse) {
        sleep(2)
        try! response.end()
    }
}

class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart

    private let expectation: XCTestExpectation

    public init(_ expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func channelInactive(context: ChannelHandlerContext) {
        expectation.fulfill()
    }
}
