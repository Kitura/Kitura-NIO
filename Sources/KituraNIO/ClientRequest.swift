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

    private var port: Int16?

    private var hostName: String?

    /// Should SSL verification be disabled
    private var disableSSLVerification = false

    /// Should HTTP/2 protocol be used
    private var useHTTP2 = false

    private var path = ""

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


    init(url: String, callback: @escaping Callback) {
        self.url = url
        self.callback = callback
    }

    public func set(_ option: Options) {
        switch(option) {
        case .schema, .hostname, .port, .path, .username, .password:
            print("Must use ClientRequest.init() to set URL components")
        case .method(let method):
            self.method = method
        case .headers(let headers):
            for (key, value) in headers {
                self.headers[key] = value
            }
        case .maxRedirects(let maxRedirects):
            self.maxRedirects = maxRedirects
        case .disableSSLVerification:
            self.disableSSLVerification = true
        case .useHTTP2:
            self.useHTTP2 = true
        }
    }

    init(options: [Options], callback: @escaping Callback) {

        self.callback = callback

        var theSchema = "http://"
        var hostName = "localhost"
        var path = ""
        var port = ""

        for option in options  {
            switch(option) {

                case .method, .headers, .maxRedirects, .disableSSLVerification, .useHTTP2:
                    // call set() for Options that do not construct the URL
                    set(option)
                case .schema(var schema):
                    if !schema.contains("://") && !schema.isEmpty {
                      schema += "://"
                    }
                    theSchema = schema
                case .hostname(let host):
                    hostName = host
                    self.hostName = host
                case .port(let thePort):
                    port = ":\(thePort)"
                    self.port = thePort
                case .path(var thePath):
                    if thePath.first != "/" {
                      thePath = "/" + thePath
                    }
                    path = thePath
                    self.path = path
                case .username(let userName):
                    self.userName = userName
                case .password(let password):
                    self.password = password
            }
        }

        // Adding support for Basic HTTP authentication
        let user = self.userName ?? ""
        let pwd = self.password ?? ""
        var authenticationClause = ""
        // If either the userName or password are non-empty, add the authenticationClause
        if (!user.isEmpty || !pwd.isEmpty) {
          authenticationClause = "\(user):\(pwd)@"
        }

        url = "\(theSchema)\(authenticationClause)\(hostName)\(port)\(path)"

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
        let hostName = URL(string: url)?.host ?? "" //TODO: what could be the failure path here
        channel = try! bootstrap.connect(host: hostName, port: Int(self.port ?? 80)).wait()
        let request = HTTPRequestHead(version: HTTPVersion(major: 1, minor:1), method: .GET, uri: self.path)
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
             clientResponse.statusCode = HTTPStatusCode(rawValue: Int(header.status.code))!
         case .body(let buffer):
             clientResponse.buffer = buffer
         case .end(_):
            clientRequest.callback(clientResponse)
            _ = clientRequest.channel.close()
         }
     }
}

