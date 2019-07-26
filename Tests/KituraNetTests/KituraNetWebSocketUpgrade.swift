//
//  KituraNetWebSocketUpgrade.swift
//  KituraNetTests
//
//  Created by Haris Kumar S on 22/07/19.
//


import Dispatch

import Foundation
@testable import KituraNet

import LoggerAPI
import NIO
import NIOHTTP1
import NIOWebSocket
import Dispatch
import CryptoKit

import Socket
import XCTest


class KituraNetWebSocketUpgradeTest:KituraNetTest{
    var httpHandler : HTTPResponseHandler?
    func clientChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        var httpRequestEncoder : HTTPRequestEncoder
        var httpResponseDecoder: ByteToMessageHandler<HTTPResponseDecoder>
        httpRequestEncoder = HTTPRequestEncoder()
        httpResponseDecoder =  ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .dropBytes))
        return channel.pipeline.addHandlers(httpRequestEncoder, httpResponseDecoder, position: .last).flatMap {_ in
            channel.pipeline.addHandler(self.httpHandler!)
        }
    }

    
    func testWebSocketUpgrade () {
        let factory = WSConnectionUpgradeFactory()
        let delegate = WebSocketUpgradeDelegate()
        factory.register(service: WebSocketService(), onPath: "/wstester")
        performServerTest(delegate, socketType: .tcp, useSSL: false, allowPortReuse: true, asyncTasks:{ expectation in
            let upgraded = DispatchSemaphore(value: 0)
            self.sendUpgradeRequest(toPath: "/wstester", usingKey: "test", wsVersion: "13", semaphore: upgraded)
            upgraded.wait()
            XCTAssertEqual(self.httpHandler!.responseStatus, .switchingProtocols, "Protocol upgrade to websocket failed with response code \(self.httpHandler!.responseStatus)")
            expectation.fulfill()
            
        },{expectation in
            let upgraded = DispatchSemaphore(value: 0)
            self.sendUpgradeRequest(toPath: "/wstester", usingKey: "test", wsVersion: "12", semaphore: upgraded)
            upgraded.wait()
            XCTAssertEqual(self.httpHandler!.responseStatus, .badRequest, "Test case failed as status code \(self.httpHandler!.responseStatus) was returned instead of badRequest " )
            expectation.fulfill()
            
        },{expectation in
            let upgraded = DispatchSemaphore(value: 0)
            self.sendUpgradeRequest(toPath: "/", usingKey: "test", wsVersion: "13", semaphore: upgraded)
            upgraded.wait()
            XCTAssertEqual(self.httpHandler!.responseStatus, .badRequest, "Test case failed as status code    \(self.httpHandler!.responseStatus) was returned instead of badRequest")
            expectation.fulfill()
            
        },{expectation in
            let upgraded = DispatchSemaphore(value: 0)
            self.sendUpgradeRequest(toPath: "/", usingKey: "test", wsVersion: "1", semaphore: upgraded)
            upgraded.wait()
            XCTAssertEqual(self.httpHandler!.responseStatus, .badRequest, "Test case failed as status code \(self.httpHandler!.responseStatus) was returned instead of badRequest")
            expectation.fulfill()
            
        })
}
    
    class WebSocketUpgradeDelegate: ServerDelegate {
        func handle(request: ServerRequest, response: ServerResponse) {}
    }
    
    func sendUpgradeRequest(toPath: String, usingKey: String, wsVersion: String, semaphore: DispatchSemaphore, errorMessage: String? = nil) {
        
        self.httpHandler = HTTPResponseHandler(key: usingKey,semaphore: semaphore, errorMessage: errorMessage)
        let clientBootstrap = ClientBootstrap(group: MultiThreadedEventLoopGroup(numberOfThreads: 1))
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)
            .channelInitializer(clientChannelInitializer)
        
        do {
            let channel = try clientBootstrap.connect(host: "localhost", port: self.port).wait()
            var request = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1), method: HTTPMethod(rawValue: "GET"), uri: toPath)
            var headers = HTTPHeaders()
            headers.add(name: "Upgrade", value: "websocket")
            headers.add(name: "Connection", value: "Upgrade")
            headers.add(name: "Sec-WebSocket-Version", value: wsVersion)
            headers.add(name: "Sec-WebSocket-Key", value: usingKey)
            request.headers = headers
            channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
            try channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil))).wait()
        } catch let error {
            Log.error("Error: \(error)")
    }
}
}

class HTTPResponseHandler: ChannelInboundHandler {
    
    public typealias InboundIn = HTTPClientResponsePart
    public var responseStatus : HTTPResponseStatus

    let errorMessage: String?
    let key: String
    let upgradeDoneOrRefused: DispatchSemaphore
    
    public init(key: String, semaphore: DispatchSemaphore, errorMessage: String? = nil) {
        self.key = key
        self.upgradeDoneOrRefused = semaphore
        self.errorMessage = errorMessage
        self.responseStatus = .ok
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny){
        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let header):
            responseStatus = header.status
            upgradeDoneOrRefused.signal()
        case .body(_):
            break
        case .end(_):
            break
        }
    }
}

public class WebSocketHandler: ChannelInboundHandler{
    public typealias InboundIn = NIOAny
}

public class WSConnectionUpgradeFactory: ProtocolHandlerFactory {
    
    public var name = "websocket"
    private var registry: [String: WebSocketService] = [:]

    
    init() {
        ConnectionUpgrader.register(handlerFactory: self)
        //We configure the default `permessage-deflate` extension here.
    }

    public func handler(for request: ServerRequest) -> ChannelHandler {
        return WebSocketHandler()
    }
    
    public func isServiceRegistered(at path: String) -> Bool {
        return self.registry[path] != nil
    }
    
    public func extensionHandlers(header: String) -> [ChannelHandler] {
        let handlers: [ChannelHandler] = []
        return handlers
    }
    
    public func negotiate(header: String) -> String {
        return ""
    }
    
    func register(service: WebSocketService, onPath: String) {
        let path: String
        if onPath.hasPrefix("/") {
            path = onPath
        } else {
            path = "/" + onPath
        }
        registry[path] = service
    }
}

public class WebSocketService { }

