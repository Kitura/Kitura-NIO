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

    /// An alternate backing store of type `NIOHTTP1.HTTPHeader` used to avoid translations between HeadersContainer and HTTPHeaders
    var nioHeaders: HTTPHeaders = HTTPHeaders()
    
    /// Create an instance of `HeadersContainer`
    public init() {}

    /// A special initializer for HTTPServerRequest, to make the latter better performant
    init(with nioHeaders: HTTPHeaders) {
        self.nioHeaders = nioHeaders
    }

    private enum _Mode {
        case nio  // Headers are simply backed up by `NIOHTTP1.HTTPHeaders`
        case dual // Headers are backed up by a dictionary as well, we switch to this mode while using HeadersContainer as Collection
    }

    // The default mode is nio
    private var mode: _Mode = .nio

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
                nioHeaders.replace(name: key, values: newValue)
                if mode == .dual {
                    set(key, value: newValue)
                }
            }
            else {
                nioHeaders.remove(name: key)
                if mode == .dual {
                    remove(key)
                }
            }
        }
    }

    /// Append values to an HTTP header
    ///
    /// - Parameter key: The HTTP header key
    /// - Parameter value: An array of strings to add as values of the HTTP header
    public func append(_ key: String, value: [String]) {
        let lowerCaseKey = key.lowercased()
        var entry = nioHeaders[key]
        
        switch(lowerCaseKey) {

        case "set-cookie":
            if entry.count > 0 {
                entry += value
                nioHeaders.replace(name: key, values: entry)
                if mode == .dual {
                    headers[lowerCaseKey]?.value += value
                }
            } else {
                nioHeaders.add(name: key, values: value)
                if mode == .dual {
                    set(key, lowerCaseKey: lowerCaseKey, value: value)
                }
            }

        case "content-type", "content-length", "user-agent", "referer", "host",
             "authorization", "proxy-authorization", "if-modified-since",
             "if-unmodified-since", "from", "location", "max-forwards",
             "retry-after", "etag", "last-modified", "server", "age", "expires":
            if entry.count > 0 {
                Log.warning("Duplicate header \(key) discarded")
                break
            }
            fallthrough

        default:
            if nioHeaders[key].count == 0 {
                nioHeaders.add(name: key, values: value)
                if mode == .dual {
                    set(key, lowerCaseKey: lowerCaseKey, value: value)
                }
            } else {
                let oldValue = nioHeaders[key].first!
                let newValue = oldValue + ", " + value.joined(separator: ", ")
                nioHeaders.replaceOrAdd(name: key, value: newValue)
                if mode == .dual {
                   headers[lowerCaseKey]?.value[0] = newValue
                }
            }
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
        let values = nioHeaders[key]
        // `HTTPHeaders.subscript` returns a [] if no header is found, but `HeadersContainer` is expected to return a nil
        return values.count > 0 ? values : nil
    }

    /// Remove all of the headers
    public func removeAll() {
        nioHeaders = HTTPHeaders()
        if mode == .dual {
            headers.removeAll(keepingCapacity: true)
        }
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

    func checkAndSwitchToDualMode() {
        guard mode == .nio else { return }
        mode = .dual
        for header in nioHeaders {
            headers[header.name.lowercased()] = (header.name, nioHeaders[header.name])
        }
    }
}

extension HTTPHeaders {
    mutating func add(name: String, values: [String]) {
        values.forEach {
            self.add(name: name, value: $0)
        }
    }

    mutating func replace(name: String, values: [String]) {
        self.replaceOrAdd(name: name, value: values[0])
        for value in values.suffix(from: 1) {
           self.add(name: name, value: value)
        }
    }
}
/// Conformance to the `Collection` protocol
/// As soon as either of these properties or methods are invoked, we need to switch to the `dual` mode of operation
extension HeadersContainer: Collection {

    public typealias Index = DictionaryIndex<String, (key: String, value: [String])>

    /// The starting index of the `HeadersContainer` collection
    public var startIndex:Index {
        checkAndSwitchToDualMode()
        return headers.startIndex
    }

    /// The ending index of the `HeadersContainer` collection
    public var endIndex:Index {
        checkAndSwitchToDualMode()
        return headers.endIndex
    }

    /// Get a (key value) tuple from the `HeadersContainer` collection at the specified position.
    ///
    /// - Parameter position: The position in the `HeadersContainer` collection of the
    ///                      (key, value) tuple to return.
    ///
    /// - Returns: A (key, value) tuple.
    public subscript(position: Index) -> (key: String, value: [String]) {
        get {
            checkAndSwitchToDualMode()
            return headers[position].value
        }
    }

    /// Get the next Index in the `HeadersContainer` collection after the one specified.
    ///
    /// - Parameter after: The Index whose successor is to be returned.
    ///
    /// - Returns: The Index in the `HeadersContainer` collection after the one specified.
    public func index(after i: Index) -> Index {
        checkAndSwitchToDualMode()
        return headers.index(after: i)
    }
}
