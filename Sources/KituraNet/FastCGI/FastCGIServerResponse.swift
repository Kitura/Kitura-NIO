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

// TBD: Bound should be of type Int i.e. Bound == Int. Currently this syntax is unavailable, expected to be shipped with Swift 3.1.
// https://forums.developer.apple.com/thread/6627
#if !swift(>=4)
    typealias BinaryInteger = IntegerArithmetic
#endif

extension Range where Bound: BinaryInteger {
    func iterate(by delta: Bound, action: (Range<Bound>) throws -> Void) throws {

        var base = self.lowerBound

        while base < self.upperBound {
            let subRange = (base ..< (base + delta)).clamped(to: self)
            try action(subRange)

            base += delta
        }
    }
}

/// The FastCGIServerRequest class implements the `ServerResponse` protocol
/// for incoming HTTP requests that come in over a FastCGI connection.
public class FastCGIServerResponse: ServerResponse {

    /// Size of buffers (64 * 1024 is the max size for a FastCGI outbound record)
    /// Which also gives a bit more internal buffer room.
    private static let bufferSize = 64 * 1024

    /// Buffer for HTTP response line, headers, and short bodies
    private var buffer = Data(capacity: FastCGIServerResponse.bufferSize)

    /// Whether or not the HTTP response line and headers have been flushed.
    private var startFlushed = false

    /// The headers to send back as part of the HTTP response.
    public var headers = HeadersContainer()

    /// Status code
    private var status = HTTPStatusCode.OK.rawValue

    /// Corresponding server request
    private weak var serverRequest: FastCGIServerRequest?

    /// The status code to send in the HTTP response.
    public var statusCode: HTTPStatusCode? {
        get {
            return HTTPStatusCode(rawValue: status)
        }
        set (newValue) {
            if let newValue = newValue, !startFlushed {
                status = newValue.rawValue
            }
        }
    }

    /// Add a string to the body of the HTTP response and complete sending the HTTP response
    ///
    /// - Parameter text: The String to add to the body of the HTTP response.
    ///
    /// - Throws: Socket.error if an error occurred while writing to the socket
    public func end(text: String) throws {
        fatalError("FastCGI not implemented yet.")
    }

    /// Add a string to the body of the HTTP response.
    ///
    /// - Parameter string: The String data to be added.
    ///
    /// - Throws: Socket.error if an error occurred while writing to the socket
    public func write(from string: String) throws {
        fatalError("FastCGI not implemented yet.")
    }

    /// Add bytes to the body of the HTTP response.
    ///
    /// - Parameter data: The Data struct that contains the bytes to be added.
    ///
    /// - Throws: Socket.error if an error occurred while writing to the socket
    public func write(from data: Data) throws {
        fatalError("FastCGI not implemented yet.")
    }

    /// Complete sending the HTTP response
    ///
    /// - Throws: Socket.error if an error occurred while writing to a socket
    public func end() throws {
        fatalError("FastCGI not implemented yet.")
    }

    /// External message write for multiplex rejection
    ///
    /// - Parameter requestId: The id of the request to reject.
    public func rejectMultiplexConnecton(requestId: UInt16) throws {
        fatalError("FastCGI not implemented yet.")
    }

    /// External message write for role rejection
    public func rejectUnsupportedRole() throws {
        fatalError("FastCGI not implemented yet.")
    }

    /// Reset the request for reuse in Keep alive
    public func reset() {
        /*****  TBD *******/
    }
}
