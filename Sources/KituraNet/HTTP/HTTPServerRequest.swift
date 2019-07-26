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
import LoggerAPI
import Foundation

// MARK: HTTPServerRequest

/**
This class implements the `ServerRequest` protocol for incoming sockets that are communicating via the HTTP protocol. Data and Strings can be read in.

### Usage Example: ###
````swift
 func handlePost(request: ServerRequest, response: ServerResponse) {
     var body = Data()
     do {
         let length = try request.readAllData(into: &body)
         let result = "Read \(length) bytes"
         response.headers["Content-Type"] = ["text/plain"]
         response.headers["Content-Length"] = ["\(result.count)"]

         try response.end(text: result)
     }
     catch {
         print("Error reading body or writing response")
     }
 }
````
*/
public class HTTPServerRequest: ServerRequest {
    /**
     Set of HTTP headers of the request.

     ### Usage Example: ###
     ````swift
     let protocols = request.headers["Upgrade"]
     ````
    */
    public var headers: HeadersContainer

    /**
     The URL from the request in string form
     This contains just the path and query parameters starting with '/'
     Use 'urlURL' for the full URL

     ### Usage Example: ###
     ````swift
     print(request.urlString)
     ````
    */
    @available(*, deprecated, message: "This contains just the path and query parameters starting with '/'. use 'urlURL' instead")
    public var urlString: String {
        return rawURLString
    }

    /**
     The URL from the request in UTF-8 form
     This contains just the path and query parameters starting with '/'
     Use 'urlURL' for the full URL

     ### Usage Example: ###
     ````swift
     print(request.url)
     ````
    */
    public var url: Data {
        //The url needs to retain the percent encodings. URL.path doesn't, so we do this.
        return Data(rawURLString.utf8)
    }

    /**
     The URL from the request as URLComponents
     URLComponents has a memory leak on linux as of swift 3.0.1. Use 'urlURL' instead

     ### Usage Example: ###
     ````swift
     print(request.urlComponents)
     ````
    */
    @available(*, deprecated, message: "URLComponents has a memory leak on linux as of swift 3.0.1. use 'urlURL' instead")
    public var urlComponents: URLComponents {
        return URLComponents(url: urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
    }

    private var _url: URL?

    /**
     Create and validate the full URL.

     ### Usage Example: ###
     ````swift
     print(request.urlURL)
     ````
    */
    public var urlURL: URL {
        if let _url = _url {
            return _url
        }

        var url = ""
        url.append(self.enableSSL ? "https://" : "http://")

        if let hostname = headers["Host"]?.first {
            // Handle Host header values of the kind "localhost:8080"
            url.append(hostname)
            if !hostname.contains(":") {
                url.append(":")
                url.append(String(describing: self.localAddressPort))
            }
        } else {
            Log.error("Host header not received")
            let hostname = self.localAddressHost
            url.append(hostname == "127.0.0.1" ? "localhost" : hostname)
            url.append(":")
            url.append(String(describing: self.localAddressPort))
        }
        url.append(rawURLString)

        if let urlURL = URL(string: url) {
            self._url = urlURL
        } else {
            Log.error("URL init failed from: \(url)")
            self._url = URL(string: "http://not_available/")!
        }
        return self._url!
    }

    /**
     Server IP address pulled from socket.

     ### Usage Example: ###
     ````swift
     request.remoteAddress
     ````
    */
    public var remoteAddress: String

    /**
     Major version of HTTP of the request

     ### Usage Example: ###
     ````swift
     print(String(describing: request.httpVersionMajor))
     ````
    */
    public var httpVersionMajor: UInt16?

    /**
     Minor version of HTTP of the request

     ### Usage Example: ###
     ````swift
     print(String(describing: request.httpVersionMinor))
     ````
    */
    public var httpVersionMinor: UInt16?

    /**
     HTTP Method of the request.

     ### Usage Example: ###
     ````swift
     request.method.lowercased()
     ````
    */
    public var method: String

    private let channel: Channel

    private var enableSSL: Bool = false

    private var rawURLString: String

    private var urlStringPercentEncodingRemoved: String?

    // The hostname of the server
    private var localAddressHost: String

    // The port number on which the server is listening
    private var localAddressPort: Int

    private static func host(socketAddress: SocketAddress?) -> String {
        guard let socketAddress = socketAddress else {
            return ""
        }
        switch socketAddress {
        case .v4(let addr):
            return addr.host
        case .v6(let addr):
            return addr.host
        case .unixDomainSocket:
            return "uds"
        }
    }

    init(channel: Channel, requestHead: HTTPRequestHead, enableSSL: Bool) {
        // An HTTPServerRequest may be created only on the EventLoop assigned to handle
        // the connection on which the HTTP request arrived.
        assert(channel.eventLoop.inEventLoop)
        self.channel = channel
        self.headers = HeadersContainer(with: requestHead.headers)
        self.method = requestHead.method.rawValue
        self.httpVersionMajor = UInt16(requestHead.version.major)
        self.httpVersionMinor = UInt16(requestHead.version.minor)
        self.rawURLString = requestHead.uri
        self.enableSSL = enableSSL
        self.localAddressHost = HTTPServerRequest.host(socketAddress: channel.localAddress)
        self.localAddressPort = channel.localAddress?.port ?? 0
        self.remoteAddress = HTTPServerRequest.host(socketAddress: channel.remoteAddress)
    }

    var buffer: BufferList?

    /// Default buffer size used for creating a BufferList
    let bufferSize = 2048

    /**
     Read a chunk of the body of the request.

     - Parameter into: An NSMutableData to hold the data in the request.
     - Throws: if an error occurs while reading the body.
     - Returns: the number of bytes read.

     ### Usage Example: ###
     ````swift
     let readData = try self.read(into: data)
     ````
    */
    public func read(into data: inout Data) throws -> Int {
        guard buffer != nil else { return 0 }
        return buffer!.fill(data: &data)
    }

    /**
     Read a chunk of the body and return it as a String.

     - Throws: if an error occurs while reading the data.
     - Returns: an Optional string.

     ### Usage Example: ###
     ````swift
     let body = try request.readString()
     ````
    */
    public func readString() throws -> String? {
        var data = Data(capacity: bufferSize)
        let length = try read(into: &data)
        if length > 0 {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }

    /**
     Read the whole body of the request.

     - Parameter into: An NSMutableData to hold the data in the request.
     - Throws: if an error occurs while reading the data.
     - Returns: the number of bytes read.

     ### Usage Example: ###
     ````swift
     let length = try request.readAllData(into: &body)
     ````
    */
    public func readAllData(into data: inout Data) throws -> Int {
        guard buffer != nil else { return 0 }
        var length = buffer!.fill(data: &data)
        var bytesRead = length
        while length > 0 {
            length = try read(into: &data)
            bytesRead += length
        }
        return bytesRead
    }
}
