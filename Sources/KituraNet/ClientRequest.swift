/*
 * Copyright IBM Corporation 2016, 2017, 2018
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
import NIOHTTP1
import Foundation
import NIOSSL
import LoggerAPI
import Dispatch

// The public API for ClientRequest erroneously defines the port as an Int16, which is
// insufficient to hold all possible port values. To avoid a breaking change, we allow
// UInt16 bit patterns to be passed in, under the guises of an Int16, which we will
// then convert back to UInt16.
//
// User code must perform the equivalent conversion in order to pass in a value that
// is greater than Int16.max.
//
fileprivate extension Int16 {
    func toUInt16() -> UInt16 {
        return UInt16(bitPattern: self)
    }
}

fileprivate extension UInt16 {
    func toInt16() -> Int16 {
        return Int16(bitPattern: self)
    }
}

// MARK: ClientRequest
/**
This class provides a set of low level APIs for issuing HTTP requests to another server. A new instance of the request can be created, along with options if the user would like to specify certain parameters such as HTTP headers, HTTP methods, host names, and SSL credentials. `Data` and `String` objects cab be added to a `ClientRequest` too, and URLs can be parsed.

### Usage Example: ###
````swift
//Function to create a new `ClientRequest` using a URL.
 public static func request(_ url: String, callback: @escaping ClientRequest.Callback) -> ClientRequest {
     return ClientRequest(url: url, callback: callback)
 }

 //Create a new `ClientRequest` using a URL.
 let request = HTTP.request("http://localhost/8080") {response in
     ...
 }
````
*/
public class ClientRequest {

    /**
     The set of HTTP headers to be sent with the request.

     ### Usage Example: ###
     ````swift
     clientRequest.headers["Content-Type"] = ["text/plain"]
     ````
     */
    public var headers = [String: String]()

    /**
     The URL for the request.

     ### Usage Example: ###
     ````swift
     clientRequest.url = "https://localhost:8080"
     ````
     */
    public private(set) var url: String = ""

    private var percentEncodedURL: String = ""

    /**
     The HTTP method (i.e. GET, POST, PUT, DELETE) for the request.

     ### Usage Example: ###
     ````swift
     clientRequest.method = "post"
     ````
     */
    public private(set) var method: String = "get"

    /**
     The username to be used if using Basic Auth authentication.

     ### Usage Example: ###
     ````swift
     clientRequest.userName = "user1"
     ````
     */
    public private(set) var userName: String?

    /**
     The password to be used if using Basic Auth authentication.

     ### Usage Example: ###
     ````swift
     clientRequest.password = "sUpeR_seCurE_paSsw0rd"
     ````
     */
    public private(set) var password: String?

    /**
     The maximum number of redirects before failure.

     - Note: The `ClientRequest` class will automatically follow redirect responses. To avoid redirect loops, it will at maximum follow `maxRedirects` redirects.

     ### Usage Example: ###
     ````swift
     clientRequest.maxRedirects = 10
     ````
     */
    public internal(set) var maxRedirects = 10

    /**
     If true, the "Connection: close" header will be added to the request that is sent.

     ### Usage Example: ###
     ````swift
     ClientRequest.closeConnection = false
     ````
     */
    public private(set) var closeConnection = false

    /// The callback to receive the response
    private(set) var callback: Callback

    /// The hostname of the remote server
    var hostName: String?

    /// The port number of the remote server
    var port: Int?

    /// The request body
    var bodyData: Data?

    /// Should SSL verification be enabled
    private var disableSSLVerification = false {
        didSet {
            if disableSSLVerification {
                self.sslConfig = TLSConfiguration.forClient(certificateVerification: .none)
            }
        }
    }

    /// TLS Configuration
    var sslConfig: TLSConfiguration?

    /// The current redirection count
    internal var redirectCount: Int = 0

    private var sslContext: NIOSSLContext?

    /// Should HTTP/2 protocol be used
    private var useHTTP2 = false

    /// The path (uri) related to the request, starting from / and including query parameters
    private var path = ""

    /// A semaphore used to make ClientRequest.end() synchronous
    let waitSemaphore = DispatchSemaphore(value: 0)

    // Socket path for Unix domain sockets
    var unixDomainSocketPath: String?

    /**
    Client request options enum. This allows the client to specify certain parameteres such as HTTP headers, HTTP methods, host names, and SSL credentials.

    ### Usage Example: ###
    ````swift
    //If present in the options provided, the client will try to use HTTP/2 protocol for the connection.
    Options.useHTTP2
    ````
    */
    public enum Options {
        /// Specifies the HTTP method (i.e. PUT, POST...) to be sent in the request
        case method(String)

        /// Specifies the schema (i.e. HTTP, HTTPS) to be used in the URL of request
        case schema(String)

        /// Specifies the host name to be used in the URL of request
        case hostname(String)

        /// Specifies the port to be used in the URL of request.
        ///
        /// Note that an Int16 is incapable of representing all possible port values, however
        /// it forms part of the Kitura-net 2.0 API. In order to pass a port number greater
        /// than 32,767 (Int16.max), use the following code:
        /// ```
        /// let portNumber: UInt16 = 65535
        /// let portOption: ClientRequest.Options = .port(Int16(bitPattern: portNumber))
        /// ```
        case port(Int16)

        /// Specifies the path to be used in the URL of request
        case path(String)

        /// Specifies the HTTP headers to be sent with the request
        case headers([String: String])

        /// Specifies the user name to be sent with the request, when using basic auth authentication
        case username(String)

        /// Specifies the password to be sent with the request, when using basic auth authentication
        case password(String)

        /// Specifies the maximum number of redirect responses that will be followed (i.e. re-issue the
        /// request to the location received in the redirect response)
        case maxRedirects(Int)

        /// If present, the SSL credentials of the remote server will not be verified.
        case disableSSLVerification

        /// If present, the client will try to use HTTP/2 protocol for the connection.
        case useHTTP2
    }

    private func percentEncode(_ url: String) -> String {
        var _url = url
        let isPercentEncoded = _url.contains("%") && URL(string: _url) != nil
        if !isPercentEncoded {
            _url = _url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? _url
        }
        return _url
    }

    /// Initializes a `ClientRequest` instance
    ///
    /// - Parameter url: url for the request
    /// - Parameter callback: The closure of type `Callback` to be used for the callback.
    init(url: String, callback: @escaping Callback) {
        self.callback = callback
        self.url = url
        self.percentEncodedURL = percentEncode(url)

        if let url = URL(string: self.percentEncodedURL) {
            initialize(url)
        }
    }

    private func initialize(_ url: URL) {
        if let host = url.host {
            self.hostName = host
        }

        if let port = url.port {
            self.port = port
        }

        var fullPath = url.path

        // query strings and parameters need to be appended here
        if let query = url.query {
            fullPath += "?"
            fullPath += query
        }
        self.path = fullPath

        if let username = url.user {
            self.userName = username
        }

        if let password = url.password {
            self.password = password
        }

        if let username = self.userName, let password = self.password {
            self.headers["Authorization"] = createHTTPBasicAuthHeader(username: username, password: password)
        }

        self.url = "\(url.scheme ?? "http")://\(self.hostName ?? "unknown")\(self.port.map { ":\($0)" } ?? "")/\(fullPath)"
        
    }

    /**
     Set a single option in the request. URL parameters must be set in init().

     ### Usage Example: ###
     ````swift
     var options: [ClientRequest.Options] = []
     options.append(.port(Int16(port)))
     clientRequest.set(options)
     ````

     - Parameter option: An `Options` instance describing the change to be made to the request.

     */
    public func set(_ option: Options) {
        switch option {
        case .schema, .hostname, .port, .path, .username, .password:
            Log.error("Must use ClientRequest.init() to set URL components")
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

    /// Initializes a `ClientRequest` instance
    ///
    /// - Parameter options: An array of `Options' describing the request
    /// - Parameter unixDomainSocketPath: Specifies a path of a Unix domain socket that the client should connect to.
    /// - Parameter callback: The closure of type `Callback` to be used for the callback.
    init(options: [Options], unixDomainSocketPath: String? = nil, callback: @escaping Callback) {

        self.unixDomainSocketPath = unixDomainSocketPath
        self.callback = callback

        var theSchema = "http://"
        var hostName = "localhost"
        var path = ""
        var port = ""

        for option in options {
            switch option {

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
                let portNumber = thePort.toUInt16()
                port = ":\(portNumber)"
                self.port = Int(portNumber)
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

        if let username = self.userName, let password = self.password {
            self.headers["Authorization"] = createHTTPBasicAuthHeader(username: username, password: password)
        }
        //the url string
        self.url = "\(theSchema)\(hostName)\(port)\(path)"
        self.percentEncodedURL = percentEncode(self.url)
    }

    /**
     Response callback closure type.

     ### Usage Example: ###
     ````swift
     var ClientRequest.headers["Content-Type"] = ["text/plain"]
     ````

     - Parameter ClientResponse: The `ClientResponse` object that describes the response that was received from the remote server.

    */
    public typealias Callback = (ClientResponse?) -> Void

    /**
     Parse an URL (String) into an array of ClientRequest.Options.

     ### Usage Example: ###
     ````swift
     let url: String = "http://www.website.com"
     let parsedOptions = clientRequest.parse(url)
     ````

     - Parameter urlString: A String object referencing a URL.
     - Returns: An array of `ClientRequest.Options`
    */
    public class func parse(_ urlString: String) -> [ClientRequest.Options] {
        if let url = URL(string: urlString) {
            return parse(url)
        }
        return []
    }

    /**
     Parse an URL Foudation object into an array of ClientRequest.Options.

     ### Usage Example: ###
     ````swift
     let url: URL = URL(string: "http://www.website.com")!
     let parsedOptions = clientRequest.parse(url)
     ````

     - Parameter url: Foundation URL object.
     - Returns: An array of `ClientRequest.Options`
    */
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
            options.append(.port(Int16(bitPattern: UInt16(port))))
        }
        if let username = url.user {
            options.append(.username(username))
        }
        if let password = url.password {
            options.append(.password(password))
        }
        return options
    }

    /**
     Add a String to the body of the request to be sent.

     ### Usage Example: ###
     ````swift
     let stringToSend: String = "send something"
     clientRequest.write(from: stringToSend)
     ````

     - Parameter from: The String to be added to the request.
     */
    public func write(from string: String) {
        write(from: Data(string.utf8))
    }

    /**
     Add the bytes in a Data struct to the body of the request to be sent.

     ### Usage Example: ###
     ````swift
     let string = "some some more stuff"
     if let data: Data = string.data(using: .utf8) {
        clientRequest.write(from: data)
     }

     ````

     - Parameter from: The Data Struct containing the bytes to be added to the request.
     */
    public func write(from data: Data) {
        if bodyData == nil {
            bodyData = Data()
        }
        bodyData!.append(data)
        headers["Content-Length"] = "\(bodyData!.count)" //very eagerly adding
    }

    /**
     Add a String to the body of the request to be sent and then send the request to the remote server.

     ### Usage Example: ###
     ````swift
     let data: String = "send something"
     clientRequest.end(from: data, close: true)
     ````

     - Parameter data: The String to be added to the request.
     - Parameter close: If true, add the "Connection: close" header to the set of headers sent with the request.
     */
    public func end(_ data: String, close: Bool = false) {
        write(from: data)
        end(close: close)
    }

    /**
     Add the bytes in a Data struct to the body of the request to be sent and then send the request to the remote server.

     ### Usage Example: ###
     ````swift
     let stringToSend = "send this"
     let data: Data = stringToSend.data(using: .utf8) {
        clientRequest.end(from: data, close: true)
     }
     ````

     - Parameter data: The Data struct containing the bytes to be added to the request.
     - Parameter close: If true, add the "Connection: close" header to the set of headers sent with the request.
     */
    public func end(_ data: Data, close: Bool = false) {
        write(from: data)
        end(close: close)
    }

    /// The channel connecting to the remote server
    var channel: Channel?

    /// The client bootstrap used to connect to the remote server
    var bootstrap: ClientBootstrap?

    /**
     Send the request to the remote server.

     ### Usage Example: ###
     ````swift
     clientRequest.end(true)
     ````

     - Parameter close: If true, add the "Connection: close" header to the set of headers sent with the request.
     */
    public func end(close: Bool = false) {
        closeConnection = close

        var isHTTPS = false

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        if (URL(string: percentEncodedURL)?.scheme)! == "https" {
           isHTTPS = true
           self.sslConfig = TLSConfiguration.forClient(certificateVerification: .none)
        }

        if isHTTPS {
            initializeClientBootstrapWithSSL(eventLoopGroup: group)
        } else {
            initializeClientBootstrap(eventLoopGroup: group)
        }

        let hostName = URL(string: percentEncodedURL)?.host ?? "" //TODO: what could be the failure path here
        let portNumber = URL(string: percentEncodedURL)?.port ?? 8080
        if self.headers["Host"] == nil {
           let isNotDefaultPort = (portNumber != 443 && portNumber != 80) //Check whether port is not 443/80
           self.headers["Host"] = hostName + (isNotDefaultPort ? (":" + String(portNumber)) : "")
        }

        // To keep Kitura-NIO's behaviour similar to Kitura-net, add the Accept header with default value '*/*'.
        // Note:libcurl adds default value for Accept header for Kitura-net
        if self.headers["Accept"] == nil && self.headers["accept"] == nil {
           self.headers["Accept"] = "*/*"
        }

        self.headers["User-Agent"] = "Kitura"

        if closeConnection {
            self.headers["Connection"] = "close"
        }

        if self.port == nil {
            self.port = isHTTPS ? 443 : 80
        }

        //If the path is empty, set it to /
        let path = self.path == "" ? "/" : self.path

        defer {
            do {
                try group.syncShutdownGracefully()
            } catch {
                Log.error("ClientRequest failed to shut down the EventLoopGroup for the requested URL: \(url)")
            }
        }

        do {
            guard let bootstrap = bootstrap else { return }
            if let unixDomainSocketPath = self.unixDomainSocketPath {
                channel = try bootstrap.connect(unixDomainSocketPath: unixDomainSocketPath).wait()
            } else {
                channel = try bootstrap.connect(host: hostName, port: Int(self.port!)).wait()
            }
        } catch let error {
            let target = self.unixDomainSocketPath ?? "\(self.port ?? 80)"
            Log.error("Connection to \(hostName): \(target) failed with error: \(error)")
            callback(nil)
            return
        }

        var request = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1), method: HTTPMethod(rawValue: self.method.uppercased()), uri: path)
        request.headers = HTTPHeaders.from(dictionary: self.headers)

        // Make the HTTP request, the response callbacks will be received on the HTTPClientHandler.
        // We are mostly not running on the event loop. Let's make sure we send the request over the event loop.
        guard let channel = channel else { return }
        channel.eventLoop.run {
            self.sendRequest(request: request, on: channel)
        }
        waitSemaphore.wait()

        // We are now free to close the connection if asked for.
        if closeConnection {
            channel.eventLoop.run {
                channel.close(promise: nil)
            }
        }
    }

    private func sendRequest(request: HTTPRequestHead, on channel: Channel) {
        channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        if let bodyData = bodyData {
            let buffer = BufferList()
            buffer.append(data: bodyData)
            channel.write(NIOAny(HTTPClientRequestPart.body(.byteBuffer(buffer.byteBuffer))), promise: nil)
        }
        _ = channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil)))
    }

    private func initializeClientBootstrapWithSSL(eventLoopGroup: EventLoopGroup) {
        if let sslConfig = self.sslConfig {
            do {
                sslContext = try NIOSSLContext(configuration: sslConfig)
            } catch let error {
                Log.error("Failed to create SSLContext. Error: \(error)")
            }
        }

        bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(try! NIOSSLClientHandler(context: self.sslContext!, serverHostname: nil)).flatMap {
                    channel.pipeline.addHTTPClientHandlers().flatMap {
                        channel.pipeline.addHandler(HTTPClientHandler(request: self))
                    }
                }
            }
    }

    private func initializeClientBootstrap(eventLoopGroup: EventLoopGroup) {
        bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandler(HTTPClientHandler(request: self))
                }
            }
    }

    private func createHTTPBasicAuthHeader(username: String, password: String) -> String {
        let authHeader = "\(username):\(password)"
        let data = Data(authHeader.utf8)
        return "Basic \(data.base64EncodedString())"
    }
}

extension HTTPHeaders {
    static func from(dictionary: [String: String]) -> HTTPHeaders {
        var headers = HTTPHeaders()
        for (key, value) in dictionary {
            headers.add(name: key, value: value)
        }
        return headers
    }
}


/// The ChannelInboundHandler for ClientRequest
class HTTPClientHandler: ChannelInboundHandler {

     /// The ClientRequest for which we installed this handler
     private let clientRequest: ClientRequest

     /// The ClientResponse object for the response
     private var clientResponse: ClientResponse = ClientResponse()

     init(request: ClientRequest) {
         self.clientRequest = request
     }

     typealias InboundIn = HTTPClientResponsePart

     /// Read the header, body and trailer. Redirection is handled in the trailer case.
     func channelRead(context: ChannelHandlerContext, data: NIOAny) {
         let response = self.unwrapInboundIn(data)
         switch response {
         case .head(let header):
             clientResponse.httpHeaders = header.headers
             clientResponse.httpVersionMajor = UInt16(header.version.major)
             clientResponse.httpVersionMinor = UInt16(header.version.minor)
             clientResponse.statusCode = HTTPStatusCode(rawValue: Int(header.status.code))!
         case .body(var buffer):
             if clientResponse.buffer == nil {
                 clientResponse.buffer = BufferList(with: buffer)
             } else {
                 clientResponse.buffer!.byteBuffer.writeBuffer(&buffer)
             }
         case .end:
            // Handle redirection
            if clientResponse.statusCode == .movedTemporarily || clientResponse.statusCode == .movedPermanently {
                self.clientRequest.redirectCount += 1
                if self.clientRequest.redirectCount < self.clientRequest.maxRedirects {
                    guard let url = clientResponse.headers["Location"]?.first else {
                        Log.error("The server redirected but sent no Location header")
                        return
                    }
                    if url.starts(with: "/") {
                        let scheme = URL(string: clientRequest.url)?.scheme
                        var options: [ClientRequest.Options] = [.schema(scheme!), .hostname(clientRequest.hostName!), .path(url)]
                        let request: ClientRequest
                        if let socketPath = self.clientRequest.unixDomainSocketPath {
                            request = ClientRequest(options: options, unixDomainSocketPath: socketPath, callback: clientRequest.callback)
                        } else {
                            let port = clientRequest.port.map { UInt16($0) }.map { $0.toInt16() }!
                            options.append(.port(port))
                            request = ClientRequest(options: options, callback: clientRequest.callback)
                        }
                        request.maxRedirects = self.clientRequest.maxRedirects - 1

                        // The next request can be asynchronously moved to a DispatchQueue.
                        // ClientRequest.end() calls connect().wait(), so we better move this to a dispatch queue.
                        // Because ClientRequest.end() is blocking, we mark the current task complete after the new task also completes.
                        DispatchQueue.global().async {
                            request.end()
                            self.clientRequest.waitSemaphore.signal()
                        }
                    } else {
                        let request = ClientRequest(url: url, callback: clientRequest.callback)
                        request.maxRedirects = self.clientRequest.maxRedirects - 1
                        DispatchQueue.global().async {
                            request.end()
                            self.clientRequest.waitSemaphore.signal()
                        }
                    }
                } else {
                    // The callback may start a new ClientRequest eventually calling wait(), lets invoke the callback on a DispatchQueue
                    DispatchQueue.global().async {
                        self.clientRequest.callback(self.clientResponse)
                        self.clientRequest.waitSemaphore.signal()
                    }
                }
            } else {
                DispatchQueue.global().async {
                    self.clientRequest.callback(self.clientResponse)
                    self.clientRequest.waitSemaphore.signal()
                }
            }
         }
     }

     func errorCaught(ctx: ChannelHandlerContext, error: Error) {
         // No errors to handle, simply close the channel
         Log.error("ClientRequest: Error \(error) was received. The connection will be closed because we are neither handling this error nor can it be propagated.")
         ctx.close(promise: nil)
     }
}
