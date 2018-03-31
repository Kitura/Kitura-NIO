import NIO
import NIOHTTP1
import Foundation


public class HTTPServerRequest: ServerRequest {

    public var headers : HeadersContainer

    //@available(*, deprecated, message: "This contains just the path and query parameters starting with '/'. use 'urlURL' instead")
    public var urlString : String 

    public var url : Data {
        return urlURL.absoluteString.data(using: .utf8) ?? Data()
    }
    //@available(*, deprecated, message: "URLComponents has a memory leak on linux as of swift 3.0.1. use 'urlURL' instead")
    public var urlComponents : URLComponents {
        return URLComponents(url: urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
    }

    private var _url: URL?

    public var urlURL : URL {
        if let _url = _url {
            return _url
        }
        var url = ""
        //TODO: http or https?
        url.append("http://")
        let hostname = localAddress.components(separatedBy: "]").last?.components(separatedBy: ":").first ?? "Host_Not_Available"
        url.append(hostname == "127.0.0.1" ? "localhost" : hostname)
        url.append(":")
        url.append(localAddress.components(separatedBy: "]").last?.components(separatedBy: ":").last ?? "")
        url.append(urlString)
   
         if let urlURL = URL(string: url) {
            self._url = urlURL
        } else {
            self._url = URL(string: "http://not_available/")!
        }
        
        return self._url!
    }

    public var remoteAddress: String
    
    public var httpVersionMajor: UInt16?

    public var httpVersionMinor: UInt16?
    
    public var method: String

    private let localAddress: String

    init(ctx: ChannelHandlerContext, requestHead: HTTPRequestHead) {
        self.headers = HeadersContainer.create(from: requestHead.headers)
        self.method = String(describing: requestHead.method)
        self.httpVersionMajor = requestHead.version.major
        self.httpVersionMinor = requestHead.version.minor
        self.urlString = requestHead.uri
        self.remoteAddress = ctx.remoteAddress?.description.components(separatedBy: ":").first?.components(separatedBy: "]").last ?? ""
        self.localAddress = ctx.localAddress?.description ?? ""
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
