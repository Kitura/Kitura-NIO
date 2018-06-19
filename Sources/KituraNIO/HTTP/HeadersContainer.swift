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
import NIO
import NIOHTTP1
import LoggerAPI

/// A class that abstracts out the HTTP header APIs of the `ServerRequest` and
/// `ServerResponse` protocols.
public class HeadersContainer {

    /// The header storage
    internal var headers: [String: (key: String, value: [String])] = [:]
    
    /// Will be used only by ServerResponse
    internal var httpHeaders = HTTPHeaders()

    /// Create an instance of `HeadersContainer`
    public init() {}

    /// Access the value of a HTTP header using subscript syntax.
    ///
    /// - Parameter key: The HTTP header key
    ///
    /// - Returns: An array of strings representing the set of values for the HTTP
    ///           header key. If the HTTP header is not found, nil will be returned.
    public subscript(key: String) -> [String]? {
        get {
            return get(key)
        }
        
        set(newValue) {
            if let newValue = newValue {
                set(key, value: newValue)
                httpHeaders.replaceOrAdd(name: key, values: newValue)
            }
            else {
                remove(key)
                httpHeaders.remove(name: key)
            }
        }
    }

    /// Append values to an HTTP header
    ///
    /// - Parameter key: The HTTP header key
    /// - Parameter value: An array of strings to add as values of the HTTP header
    public func append(_ key: String, value: [String]) {
        
        let lowerCaseKey = key.lowercased()
        let entry = headers[lowerCaseKey]
        
        switch(lowerCaseKey) {
            
        case "set-cookie":
            if let _ = entry {
                headers[lowerCaseKey]?.value += value
            } else {
                set(key, lowerCaseKey: lowerCaseKey, value: value)
            }
            httpHeaders.add(name: key, values: value)
            
        case "content-type", "content-length", "user-agent", "referer", "host",
             "authorization", "proxy-authorization", "if-modified-since",
             "if-unmodified-since", "from", "location", "max-forwards",
             "retry-after", "etag", "last-modified", "server", "age", "expires":
            if let _ = entry {
                Log.warning("Duplicate header \(key) discarded")
                break
            }
            fallthrough
            
        default:
            guard let oldValue = entry?.value.first else {
                set(key, lowerCaseKey: lowerCaseKey, value: value)
                httpHeaders.add(name: key, values: value)
                return
            }
            let newValue = oldValue + ", " + value.joined(separator: ", ")
            headers[lowerCaseKey]?.value[0] = newValue
            httpHeaders.replaceOrAdd(name: key, value: newValue)
        }
    }

    /// Append values to an HTTP header
    ///
    /// - Parameter key: The HTTP header key
    /// - Parameter value: A string to be appended to the value of the HTTP header
    public func append(_ key: String, value: String) {
        append(key, value: [value])
    }

    private func get(_ key: String) -> [String]? {
        return headers[key.lowercased()]?.value
    }

    /// Remove all of the headers
    public func removeAll() {
        headers.removeAll(keepingCapacity: true)
        httpHeaders = HTTPHeaders()
    }
    
    private func set(_ key: String, value: [String]) {
        set(key, lowerCaseKey: key.lowercased(), value: value)
    }
    
    private func set(_ key: String, lowerCaseKey: String, value: [String]) {
        headers[lowerCaseKey] = (key: key, value: value)
    }
    
    private func remove(_ key: String) {
        headers.removeValue(forKey: key.lowercased())
    }
}

extension HTTPHeaders {
    mutating func add(name: String, values: [String]) {
        values.forEach {
            self.add(name: name, value: $0)
        }
    }

    mutating func replaceOrAdd(name: String, values: [String]) {
        values.forEach {
            replaceOrAdd(name: name, value: $0)
        }
    }
}
/// Conformance to the `Collection` protocol
extension HeadersContainer: Collection {

    public typealias Index = DictionaryIndex<String, (key: String, value: [String])>

    /// The starting index of the `HeadersContainer` collection
    public var startIndex:Index { return headers.startIndex }

    /// The ending index of the `HeadersContainer` collection
    public var endIndex:Index { return headers.endIndex }

    /// Get a (key value) tuple from the `HeadersContainer` collection at the specified position.
    ///
    /// - Parameter position: The position in the `HeadersContainer` collection of the
    ///                      (key, value) tuple to return.
    ///
    /// - Returns: A (key, value) tuple.
    public subscript(position: Index) -> (key: String, value: [String]) {
        get {
            return headers[position].value
        }
    }

    /// Get the next Index in the `HeadersContainer` collection after the one specified.
    ///
    /// - Parameter after: The Index whose successor is to be returned.
    ///
    /// - Returns: The Index in the `HeadersContainer` collection after the one specified.
    public func index(after i: Index) -> Index {
        return headers.index(after: i)
    }
}

/// Kitura uses HeadersContainer and NIOHTTP1 expects HTTPHeader - bridging methods
extension HeadersContainer {
    /// HTTPHeaders to HeadersContainer
    static func create(from httpHeaders: HTTPHeaders) -> HeadersContainer {
        let headerContainer = HeadersContainer()
        for header in httpHeaders {
            headerContainer.append(header.name, value: header.value)
        }
        return headerContainer
    }
}

