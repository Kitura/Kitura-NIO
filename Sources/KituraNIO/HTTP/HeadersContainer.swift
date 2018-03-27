import Foundation
import NIO
import NIOHTTP1

//public typealias HeadersContainer = HTTPHeaders

public extension HTTPHeaders {

    public mutating func append(_ key: String, value: String) {
        add(name: key, value: value)
    }

    public mutating func removeAll() {
        for header in self {
            self.remove(name: header.name)
        }
    }
}
