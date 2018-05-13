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

/// This class implements the `ServerRequest` protocol for incoming sockets that
/// are communicating via the HTTP protocol.
public class HTTPServerRequest: ServerRequest {

    /// Set of HTTP headers of the request.
    public var headers : HeadersContainer

    @available(*, deprecated, message: "This contains just the path and query parameters starting with '/'. use 'urlURL' instead")
    public var urlString : String 


    /// The URL from the request in UTF-8 form
    /// This contains just the path and query parameters starting with '/'
    /// Use 'urlURL' for the full URL
    public var url : Data {
        //The url needs to retain the percent encodings. URL.path doesn't, so we do this.
        let components = urlURL.absoluteString.components(separatedBy: "/")
        let path = "/" + components.dropFirst(3).joined(separator: "/")
        return path.data(using: .utf8) ?? Data()
    }

    @available(*, deprecated, message: "URLComponents has a memory leak on linux as of swift 3.0.1. use 'urlURL' instead")
    public var urlComponents : URLComponents {
        return URLComponents(url: urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
    }

    private var _url: URL?

    public var urlURL : URL {
        if let _url = _url {
            return _url
        }
        var url = ""

        self.enableSSL ? url.append("https://") : url.append("http://")

        if let hostname = headers["Host"]?.first {
            url.append(hostname)
            if !hostname.contains(":") {
                url.append(":")
                url.append(localAddress.components(separatedBy: "]").last?.components(separatedBy: ":").last ?? "")
            }
        } else {
            Log.error("Host header not received")
            let hostname = localAddress.components(separatedBy: "]").last?.components(separatedBy: ":").first ?? "Host_Not_Available"
            url.append(hostname == "127.0.0.1" ? "localhost" : hostname)
            url.append(":")
            url.append(localAddress.components(separatedBy: "]").last?.components(separatedBy: ":").last ?? "")
        }

        url.append(urlString)

   
        if let urlURL = URL(string: url) {
            self._url = urlURL
        } else {
            Log.error("URL init failed from: \(url)")
            self._url = URL(string: "http://not_available/")!
        }
        
        return self._url!
    }

    /// Server IP address pulled from socket.
    public var remoteAddress: String
    
    /// Minor version of HTTP of the request
    public var httpVersionMajor: UInt16?

    /// Major version of HTTP of the request
    public var httpVersionMinor: UInt16?

    /// HTTP Method of the request.
    public var method: String

    private let localAddress: String

    private var enableSSL: Bool = false

    init(ctx: ChannelHandlerContext, requestHead: HTTPRequestHead, enableSSL: Bool) {
        self.headers = HeadersContainer.create(from: requestHead.headers)
        self.method = String(describing: requestHead.method)
        self.httpVersionMajor = requestHead.version.major
        self.httpVersionMinor = requestHead.version.minor
        self.urlString = requestHead.uri
        //TODO: Handle the IPv6 case
        self.remoteAddress = ctx.remoteAddress?.description.components(separatedBy: ":").first?.components(separatedBy: "]").last ?? ""
        self.localAddress = ctx.localAddress?.description ?? ""
        self.enableSSL = enableSSL
    } 

    var buffer: BufferList?

    /// Default buffer size used for creating a BufferList
    let bufferSize = 2048

    /// Read a chunk of the body of the request.
    ///
    /// - Parameter into: An NSMutableData to hold the data in the request.
    /// - Throws: if an error occurs while reading the body.
    /// - Returns: the number of bytes read.
    public func read(into data: inout Data) throws -> Int {
        guard buffer != nil else { return 0 }
        return buffer!.fill(data: &data)
    }

    /// Read the whole body of the request.
    ///
    /// - Parameter into: An NSMutableData to hold the data in the request.
    /// - Throws: if an error occurs while reading the data.
    /// - Returns: the number of bytes read.
    public func readString() throws -> String? {
        var data = Data(capacity: bufferSize)
        let length = try read(into: &data)
        if length > 0 {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }

    /// Read the whole body of the request.
    ///
    /// - Parameter into: An NSMutableData to hold the data in the request.
    /// - Throws: if an error occurs while reading the data.
    /// - Returns: the number of bytes read.
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
