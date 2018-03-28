import NIO
import NIOHTTP1
import Foundation


public class HTTPServerRequest: ServerRequest {

    public var headers : HeadersContainer

    //@available(*, deprecated, message: "This contains just the path and query parameters starting with '/'. use 'urlURL' instead")
    public var urlString : String 

    public var url : Data 

    //@available(*, deprecated, message: "URLComponents has a memory leak on linux as of swift 3.0.1. use 'urlURL' instead")
    public var urlComponents : URLComponents

    public var urlURL : URL

    public var remoteAddress: String
    
    public var httpVersionMajor: UInt16?

    public var httpVersionMinor: UInt16?
    
    public var method: String

    init(ctx: ChannelHandlerContext, requestHead: HTTPRequestHead) {
        self.headers = HeadersContainer.create(from: requestHead.headers)
        self.method = String(describing: requestHead.method)
        self.httpVersionMajor = requestHead.version.major
        self.httpVersionMinor = requestHead.version.minor
        self.urlString = requestHead.uri
        self.url = requestHead.uri.data(using: .utf8) ?? Data()
        self.urlURL = URL(string: urlString) ?? URL(string: "")!
        self.remoteAddress = ctx.remoteAddress?.description ?? ""
        self.urlComponents = URLComponents(url: urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
    } 
   
    var buffer: ByteBuffer?

    let bufferSize = 2048

    public func read(into data: inout Data) throws -> Int {
        guard var buffer = buffer else { return 0 }
        return buffer.fill(data: &data)
    }
    
    public func readString() throws -> String? {
        var data = Data(capacity: bufferSize)
        let length = try read(into: &data)
        if length > 0 {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    public func readAllData(into data: inout Data) throws -> Int {
        guard var buffer = buffer else { return 0 }
        var length = buffer.fill(data: &data)
        var bytesRead = length
        while length > 0 {
            length = try read(into: &data)
            bytesRead += length
        }
        return bytesRead
    }
}
