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
import LoggerAPI

class FastCGIRequestHandler: ChannelInboundHandler {
    typealias InboundIn = FastCGIRecord
    typealias OutboundOut = FastCGIRecord 

    private var status = Status.initial

    var serverRequest: FastCGIServerRequest?

    var serverResponse: FastCGIServerResponse?

    var server: FastCGIServer?

    private var keepAlive = false
    
    public init(_ server: FastCGIServer) {
        self.server = server
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let record = self.unwrapInboundIn(data)
        switch record.type {
        case .beginRequest:
            guard case let .beginRecordContent(_, keepAlive) = record.content else {
                //report error
                return
            }
            // Does the client want to have `keepAlive` set on the current connection?
            self.keepAlive = keepAlive == 1
            serverRequest = FastCGIServerRequest(channel: context.channel)
            serverRequest?.parse(record)
            self.status = Status.requestStarted
        case .params:
            guard case let .params(_) = record.content else {
                //report error
                return
            }
            serverRequest?.parse(record) 
            self.status = Status.headersComplete
        case .stdin:
            guard case let .data(data) = record.content else {
                //report error
                return
            }
            if data.count == 0 {
                self.status = Status.requestComplete
                serverResponse = FastCGIServerResponse(channel: context.channel, handler: self, keepAlive: keepAlive)
                let delegate = self.server?.delegate ?? FastCGIDummyServerDelegate()
                delegate.handle(request: serverRequest!, response: serverResponse!)
            }
        default:
            //Unexpected record type
            break
        }
    }
}

/// A Dummy `ServerDelegate` used when the user didn't supply a delegate, but has registerd
/// at least one ConnectionUpgradeFactory. This `ServerDelegate` will simply return 404 for
/// any requests it is asked to process.
private class FastCGIDummyServerDelegate: ServerDelegate {
    /// Handle new incoming requests to the server
    ///
    /// - Parameter request: The ServerRequest class instance for working with this request.
    ///                     The ServerRequest object enables you to get the query parameters, headers, and body amongst other
    ///                     information about the incoming request.
    /// - Parameter response: The ServerResponse class instance for working with this request.
    ///                     The ServerResponse object enables you to build and send your response to the client who sent
    ///                     the request. This includes headers, the body, and the response code.
    func handle(request: ServerRequest, response: ServerResponse){
        do {
            response.statusCode = .notFound
            try response.end()
        }
        catch {
            Log.error("Failed to send the response. Error = \(error)")
        }
    }
}
