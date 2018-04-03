import Foundation

public class URLParser : CustomStringConvertible {

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
    public var queryParameters: [String:String] = [:]
    
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

    public init (url: Data, isConnect: Bool) {
        let urlComponents = URLComponents(string: String(data: url, encoding: .utf8)!)
        self.schema = urlComponents?.scheme
        self.host = urlComponents?.host
        self.path = urlComponents?.percentEncodedPath
        self.query = urlComponents?.query
        self.fragment = urlComponents?.fragment
        self.userinfo = urlComponents?.user
        self.port = urlComponents?.port
        if let queryItems = urlComponents?.queryItems{
           queryItems.forEach { 
               self.queryParameters[$0.name] = $0.value
           }
        }
    }
}
