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
