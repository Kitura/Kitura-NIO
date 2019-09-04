/*
 * Copyright IBM Corporation 2019
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

public struct HTTPServerConfiguration {
    /// Defines the maximum size of an incoming request, in bytes. If requests are received that are larger
    /// than this limit, they will be rejected and the connection will be closed.

    public let requestSizeLimit: Int?
    
    /// Defines the maximum number of concurrent connections that a server should accept. Clients attempting
    /// to connect when this limit has been reached will be rejected.
    public let connectionLimit: Int?
    
    public static var `default` = HTTPServerConfiguration(requestSizeLimit: 1024 * 1024, connectionLimit: 1024)
    
    
    /// Create an `HTTPServerConfiguration` to determine the behaviour of a `Server`.
    ///
    /// - parameter requestSizeLimit: The maximum size of an incoming request. Defaults to `IncomingSocketOptions.defaultRequestSizeLimit`.
    /// - parameter connectionLimit: The maximum number of concurrent connections. Defaults to `IncomingSocketOptions.defaultConnectionLimit`.
    
    public init(requestSizeLimit: Int?,connectionLimit: Int?)
    {
        self.requestSizeLimit = requestSizeLimit
        self.connectionLimit = connectionLimit
    }
    
}
