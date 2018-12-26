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

import Foundation

/// Splits and parses URLs into components - scheme, host, port, path, query string etc. according to the following format:
///	**scheme:[//[user:password@]host[:port]][/]path[?query][#fragment]**
/// We use the URLComponents class from Foundation here.

public class URLParser: CustomStringConvertible {

    /// Schema.
    public var schema: String?

    /// Hostname.
    public var host: String?

    /// Path portion of the URL.
    public var path: String?

    /// The entire query portion of the URL.
    public var query: String?

    /// An optional fragment identifier providing direction to a secondary resource.
    public var fragment: String?

    /// The userid and password if specified in the URL.
    public var userinfo: String?

    /// The port specified, if any, in the URL.
    public var port: Int?

    /// The query parameters broken out.
    public var queryParameters: [String: String] = [:]

    /// Nicely formatted description of the parsed result.
    public var description: String {
        var desc = ""

        if let schema = schema {
            desc += "schema: \(schema) "
        }
        if let host = host {
            desc += "host: \(host) "
        }
        if let port = port {
            desc += "port: \(port) "
        }
        if let path = path {
            desc += "path: \(path) "
        }
        if let query = query {
            desc += "query: \(query) "
            desc += "parsed query: \(queryParameters) "
        }
        if let fragment = fragment {
            desc += "fragment: \(fragment) "
        }
        if let userinfo = userinfo {
            desc += "userinfo: \(userinfo) "
        }

        return desc
    }

    /// Initialize a new `URLParser` instance.
    ///     - Parameter url: The URL to be parsed.
    ///     - Parameter isConnect: A boolean, indicating whether or not a connection has been established.
    public init (url: Data, isConnect: Bool) {
        let urlComponents = URLComponents(string: String(data: url, encoding: .utf8)!)
        self.schema = urlComponents?.scheme
        self.host = urlComponents?.host
        self.path = urlComponents?.percentEncodedPath
        self.query = urlComponents?.query
        self.fragment = urlComponents?.fragment
        if let username = urlComponents?.user, let password = urlComponents?.password {
            self.userinfo = "\(username):\(password)"
        }
        self.port = urlComponents?.port
        if let queryItems = urlComponents?.queryItems {
           queryItems.forEach {
               self.queryParameters[$0.name] = $0.value
           }
        }
    }
}
