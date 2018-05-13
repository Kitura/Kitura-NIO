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
import Foundation

public class ClientResponse {

    public init() { }

    public internal(set) var httpStatusCode: HTTPStatusCode = .unknown
    
    /// HTTP Method of the incoming message.
    @available(*, deprecated, message:
    "This method never worked on Client Responses and was inherited incorrectly from a super class")
    public var method: String { return "" } 
    
    /// Major version of HTTP of the response
    public var httpVersionMajor: UInt16?
    
    /// Minor version of HTTP of the response
    public var httpVersionMinor: UInt16? 
    
    /// Set of HTTP headers of the response.
    public var headers: HeadersContainer!

    public internal(set) var status = -1 {
        didSet {
            statusCode = HTTPStatusCode(rawValue: status) ?? .unknown
        }
    }

    public internal(set) var statusCode: HTTPStatusCode = HTTPStatusCode.unknown

    private static let bufferSize = 2000

    var buffer: BufferList?

    @discardableResult
    public func read(into data: inout Data) throws -> Int {
        guard buffer != nil else { return 0 }
        return buffer!.fill(data: &data)
    }

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
