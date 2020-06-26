/*
* Copyright IBM Corporation 2020
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import NIO
import Foundation

public protocol FastCGIConnectorProtocol {
    init(url: String, documentRoot: String)

    func send(request: HTTPServerRequest,
              keepAlive: Bool,
              responseHandler: @escaping (HTTPResponseParts) -> Void) throws
}

public typealias HTTPResponseParts = (headers: [String: String], status: Int, body: Data?)

public class FastCGIConnector: FastCGIConnectorProtocol {
    
    private var url: String
    private var hostname: String? = nil
    private var port: Int? = nil
    private var channel: Channel? = nil
    private var responseReceived = DispatchSemaphore(value: 0)
    private var bootstrap: ClientBootstrap? = nil
    private var fastCGIProxyHandler = FastCGIProxyHandler()
    private var documentRoot: String
    
    deinit {
        self.channel?.close(promise: nil)
    }
    
    required public init (url: String, documentRoot: String) {
        self.url = url
        if let url = URL(string: url) {
            self.hostname = url.host
            self.port = url.port
        }
        self.documentRoot = documentRoot
    }
    
    public func close() {
        self.channel?.close(promise: nil)
    }
    
    public func send(request: HTTPServerRequest,
                     keepAlive: Bool,
                     responseHandler: @escaping (HTTPResponseParts) -> Void) throws {
        fastCGIProxyHandler.responseHandler = responseHandler
        responseReceived = DispatchSemaphore(value: 0)
        fastCGIProxyHandler.responseReceived = responseReceived
        let scriptPath = self.documentRoot + "/" + request.urlURL.lastPathComponent
        if bootstrap == nil {
            let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            bootstrap = ClientBootstrap(group: group)
                .channelInitializer { channel in
                    channel.pipeline.addHandler(FastCGIRecordEncoderHandler<FastCGIRecordEncoder>()).flatMap { _ in
                        channel.pipeline.addHandler(RequestTranslator(keepAlive: keepAlive, script: scriptPath))
                    }.flatMap { _ in
                        channel.pipeline.addHandler(FastCGIRecordDecoderHandler<FastCGIRecordDecoder>(keepAlive: keepAlive))
                    }.flatMap { _ in
                        channel.pipeline.addHandler(ResponseTranslator())
                    }.flatMap { _ in
                        channel.pipeline.addHandler(self.fastCGIProxyHandler)
                    }
            }
            
            guard let host = self.hostname, let port = self.port else { return } //TODO: throw an error
            self.channel = try! bootstrap?.connect(host: host, port: port).wait()
        }
        
        try! self.channel?.writeAndFlush(request).wait()
        responseReceived.wait()
        if keepAlive == false {
            self.channel?.close(promise: nil)
            self.bootstrap = nil
        }
    }
}

class FastCGIProxyHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPResponseParts

    var responseHandler: ((HTTPResponseParts) -> Void)? = nil
    var response: HTTPServerResponse? = nil
    var responseReceived: DispatchSemaphore? = nil

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let responseParts = self.unwrapInboundIn(data)
        guard let responseHandler = self.responseHandler else { return }
        responseReceived?.signal()
        responseHandler(responseParts)
    }
}
