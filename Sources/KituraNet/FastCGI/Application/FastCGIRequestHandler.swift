import NIO
import LoggerAPI

class FastCGIRequestHandler: ChannelInboundHandler {
    typealias InboundIn = FastCGIRecord
    typealias InboundOut = FastCGIRecord

    private var status = Status.initial

    var serverRequest: FastCGIServerRequest?

    var serverResponse: FastCGIServerResponse?

    var server: FastCGIServer?

    public init(_ server: FastCGIServer) {
        self.server = server
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let record = self.unwrapInboundIn(data)
        switch record.contentData{
        case .roleandflag(_, _):
            serverRequest = FastCGIServerRequest(channel: context.channel)
            serverRequest?.parse(record)
            self.status = Status.requestStarted
        case .params(_):
            serverRequest?.parse(record)
            self.status = Status.headersComplete
        case .status(let appStatus, let protocolStatus):
            print(appStatus, protocolStatus)
        case .data(_):
            self.status = Status.requestComplete
            serverResponse = FastCGIServerResponse(channel: context.channel, handler: self)
            let delegate = self.server?.delegate ?? FastCGIDummyServerDelegate()

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
