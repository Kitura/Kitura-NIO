import Foundation
import NIO
import NIOHTTP1

public class HeadersContainer {

    private var httpHeader: HTTPHeaders = HTTPHeaders()
    
    internal var headers: [String: (key: String, value: [String])] = [:]
    
    public init() {}

    public subscript(key: String) -> [String]? {
        get {
            return get(key)
        }
        
        set(newValue) {
            if let newValue = newValue {
                set(key, value: newValue)
            }
            else {
                remove(key)
            }
        }
    }
    
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
                return
            }
            let newValue = oldValue + ", " + value.joined(separator: ", ")
            headers[lowerCaseKey]?.value[0] = newValue
        }
    }
    
    public func append(_ key: String, value: String) {
        append(key, value: [value])
    }

    private func get(_ key: String) -> [String]? {
        return headers[key.lowercased()]?.value
    }
    
    public func removeAll() {
        headers.removeAll(keepingCapacity: true)
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

extension HeadersContainer: Collection {

    public typealias Index = DictionaryIndex<String, (key: String, value: [String])>

    public var startIndex:Index { return headers.startIndex }

    public var endIndex:Index { return headers.endIndex }

    public subscript(position: Index) -> (key: String, value: [String]) {
        get {
            return headers[position].value
        }
    }

    public func index(after i: Index) -> Index {
        return headers.index(after: i)
    }
}

extension HeadersContainer {

    func httpHeaders() -> HTTPHeaders {
        var httpHeaders = HTTPHeaders()
        for h in self.headers {
            let header = h.value
            httpHeaders.add(name: header.key, value: header.value.joined(separator: ", "))
        }
        return httpHeaders
    }
}

extension HTTPHeaders {

    static func create(httpHeaders: HTTPHeaders) -> HeadersContainer {
        let headerContainer = HeadersContainer()
        for header in httpHeaders {
            headerContainer.append(header.name, value: header.value)
        }
        return headerContainer
    }
}

