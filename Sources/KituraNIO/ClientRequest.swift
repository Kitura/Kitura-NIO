import NIO
import NIOHTTP1
import Foundation


public class ClientRequest {
    
    public var headers = [String: String]()

    public private(set) var url: String = ""

    public private(set) var method: String = "get"

    public private(set) var userName: String?

    public private(set) var password: String?

    public private(set) var maxRedirects = 10

    public private(set) var closeConnection = false

    public private(set) var callback: Callback

    public enum Options {
        case method(String)

        case schema(String)
  
        case hostname(String)

        case port(Int16)

        case path(String)

        case headers([String: String])

        case username(String)

        case password(String)

        case maxRedirects(Int)

        case disableSSLVerification

        case useHTTP2
    }

    private let hostName: String

    init(url: String, callback: @escaping Callback) {
        self.url = url
        self.callback = callback
        self.hostName = URL(string: url)?.host ?? ""
    }

    public typealias Callback = (ClientResponse?) -> Void

    public class func parse(_ url: URL) -> [ClientRequest.Options] {

        var options: [ClientRequest.Options] = []

        if let scheme = url.scheme {
            options.append(.schema("\(scheme)://"))
        }
        if let host = url.host {
            options.append(.hostname(host))
        }
        var fullPath = url.path
        // query strings and parameters need to be appended here
        if let query = url.query {
            fullPath += "?"
            fullPath += query
        }
        options.append(.path(fullPath))
        if let port = url.port {
            options.append(.port(Int16(port)))
        }
        if let username = url.user {
            options.append(.username(username))
        }
        if let password = url.password {
            options.append(.password(password))
        }
        return options
    }

    public func write(from string: String) {
        if let data = string.data(using: .utf8) {
            write(from: data)
        }
    }

    public func write(from data: Data) {
    }

    public func end(_ data: String, close: Bool = false) {
        write(from: data)
        end(close: close)
    }

    public func end(_ data: Data, close: Bool = false) {
        write(from: data)
        end(close: close)
    }

    var channel: Channel!

    public func end(close: Bool = false) {
        //TODO: Handle redirection
        let group = MultiThreadedEventLoopGroup(numThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().then {
                    channel.pipeline.add(handler: HTTPClientHandler(request: self))
                }
            }
        
        channel = try! bootstrap.connect(host: hostName, port: 80).wait()
        let request = HTTPRequestHead(version: HTTPVersion(major: 1, minor:1), method: .GET, uri: "/get")
        channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        try! channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil))).wait()
        try! channel.closeFuture.wait()       
    }
}

public class HTTPClientHandler: ChannelInboundHandler {
   
     private var clientResponse: ClientResponse = ClientResponse()

     private let clientRequest: ClientRequest

     init(request: ClientRequest) {
         self.clientRequest = request
     }

     public typealias InboundIn = HTTPClientResponsePart

     public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
         let request = self.unwrapInboundIn(data)
         switch request {
         case .head(let header):
             clientResponse.headers = HeadersContainer.create(from: header.headers)
             clientResponse.httpVersionMajor = header.version.major
             clientResponse.httpVersionMinor = header.version.minor
             clientResponse.httpStatusCode = HTTPStatusCode(rawValue: Int(header.status.code))!
         case .body(let buffer):
             clientResponse.buffer = buffer
         case .end(_):
            clientRequest.callback(clientResponse)
            _ = clientRequest.channel.close()
         }
     }
}

