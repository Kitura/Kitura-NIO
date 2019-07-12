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

/// This class describes the response sent by the remote server to an HTTP request
/// sent using the `ClientRequest` class.
public class ClientResponse {

    public init() { }

    public private(set) var httpStatusCode: HTTPStatusCode = .unknown

    /// HTTP Method of the incoming message.
    @available(*, deprecated, message:
    "This method never worked on Client Responses and was inherited incorrectly from a super class")
    public var method: String { return "" }

    /// Major version of HTTP of the response
    public var httpVersionMajor: UInt16?

    /// Minor version of HTTP of the response
    public var httpVersionMinor: UInt16?

    internal var httpHeaders: HTTPHeaders?

    /// Set of HTTP headers of the response.
    public var headers: HeadersContainer {
        get {
            guard let httpHeaders = httpHeaders else {
                return HeadersContainer()
            }
            return HeadersContainer(with: httpHeaders)
        }

        set {
           httpHeaders = newValue.nioHeaders
        }
    }
    /// The HTTP Status code, as an Int, sent in the response by the remote server.
    public internal(set) var status = -1

    /// The HTTP Status code, as an `HTTPStatusCode`, sent in the response by the remote server.
    public internal(set) var statusCode: HTTPStatusCode = HTTPStatusCode.unknown {
        didSet {
            httpStatusCode = statusCode
            status = statusCode.rawValue
        }
    }

    /// Default buffer size to read the response into
    private static let bufferSize = 2000

    /// BufferList instance for storing the response
    var buffer: BufferList?

    /// Read a chunk of the body of the response.
    ///
    /// - Parameter into: An NSMutableData to hold the data in the response.
    /// - Throws: if an error occurs while reading the body.
    /// - Returns: the number of bytes read.
    @discardableResult
    public func read(into data: inout Data) throws -> Int {
        guard buffer != nil else { return 0 }
        return buffer!.fill(data: &data)
    }

    /// Read a chunk of the body and return it as a String.
    ///
    /// - Throws: if an error occurs while reading the data.
    /// - Returns: an Optional string.
    @discardableResult
    public func readString() throws -> String? {
        var data = Data(capacity: ClientResponse.bufferSize)
        let length = try read(into: &data)
        if length > 0 {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }

    /// Read the whole body of the response.
    ///
    /// - Parameter into: An NSMutableData to hold the data in the response.
    /// - Throws: if an error occurs while reading the data.
    /// - Returns: the number of bytes read.
    @discardableResult
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
