import NIO
import NIOHTTP1
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch
import XCTest
@testable import KituraNet
internal class HTTPConfigTestsResponseHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    let expectedSubstring: String
    let expectation: XCTestExpectation
    public init(expectation: XCTestExpectation, expectedSubstring: String ){
        self.expectedSubstring = expectedSubstring
        self.expectation = expectation
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)
        XCTAssert(response.getString(at: 0, length: response.readableBytes)?.starts(with: expectedSubstring) ?? false)
        expectation.fulfill()
    }
}

