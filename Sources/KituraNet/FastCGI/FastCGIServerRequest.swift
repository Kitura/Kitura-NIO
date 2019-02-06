/*
 * Copyright IBM Corporation 2018
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

import Foundation

import LoggerAPI

/// The FastCGIServerRequest class implements the `ServerRequest` protocol
/// for incoming HTTP requests that come in over a FastCGI connection.
public class FastCGIServerRequest: ServerRequest {

    /// The IP address of the client
    public private(set) var remoteAddress: String = ""

    /// Major version of HTTP of the request
    public private(set) var httpVersionMajor: UInt16? = 0

    /// Minor version of HTTP of the request
    public private(set) var httpVersionMinor: UInt16? = 9

    /// The set of HTTP headers received with the incoming request
    public var headers = HeadersContainer()

    /// The set of non-HTTP headers received with the incoming request
    public var fastCGIHeaders = HeadersContainer()

    /// The HTTP Method specified in the request
    public private(set) var method: String = ""

    /// URI Component received from FastCGI
    private var requestUri: String?

    public private(set) var urlURL = URL(string: "http://not_available/")!

    /// The URL from the request in string form
    /// This contains just the path and query parameters starting with '/'
    /// Use 'urlURL' for the full URL
    @available(*, deprecated, message:
    "This contains just the path and query parameters starting with '/'. use 'urlURL' instead")
    public var urlString: String { return requestUri ?? "" }

    /// The URL from the request in UTF-8 form
    /// This contains just the path and query parameters starting with '/'
    /// Use 'urlURL' for the full URL
    public var url: Data { return Data((requestUri ?? "").utf8) }

    /// The URL from the request as URLComponents
    /// URLComponents has a memory leak on linux as of swift 3.0.1. Use 'urlURL' instead
    @available(*, deprecated, message:
    "URLComponents has a memory leak on linux as of swift 3.0.1. use 'urlURL' instead")
    public lazy var urlComponents: URLComponents = { [unowned self] () in
        return URLComponents(url: self.urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        }()

    /// Chunk of body read in by the http_parser, filled by callbacks to onBody
    private var bodyChunk = BufferList()

    /// State of incoming message handling
    private var status = Status.initial

    /// The request ID established by the FastCGI client.
    public private(set) var requestId: UInt16 = 0

    /// An array of request ID's that are not our primary one.
    /// When the main request is done, the FastCGIServer can reject the
    /// extra requests as being unusable.
    public private(set) var extraRequestIds: [UInt16] = []

    /// Some defaults
    private static let defaultMethod: String = "GET"

    /// List of status states
    private enum Status {
        case initial
        case requestStarted
        case headersComplete
        case requestComplete
    }

    /// HTTP parser error types
    public enum FastCGIParserErrorType {
        case success
        case protocolError
        case invalidType
        case clientDisconnect
        case unsupportedRole
        case internalError
    }

    public init () {
    }

    /// Read data from the body of the request
    ///
    /// - Parameter data: A Data struct to hold the data read in.
    ///
    /// - Throws: Socket.error if an error occurred while reading from the socket.
    /// - Returns: The number of bytes read.
    public func read(into data: inout Data) throws -> Int {
        fatalError("FastCGI not implemented yet.")
    }

    /// Read all of the data in the body of the request
    ///
    /// - Parameter data: A Data struct to hold the data read in.
    ///
    /// - Throws: Socket.error if an error occurred while reading from the socket.
    /// - Returns: The number of bytes read.
    public func readAllData(into data: inout Data) throws -> Int {
        fatalError("FastCGI not implemented yet.")
    }

    /// Read a string from the body of the request.
    ///
    /// - Throws: Socket.error if an error occurred while reading from the socket.
    /// - Returns: An Optional string.
    public func readString() throws -> String? {
        fatalError("FastCGI not implemented yet.")
    }
}
