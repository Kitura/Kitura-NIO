import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import LoggerAPI
import Foundation
import Dispatch

internal class RequestTranslator: ChannelOutboundHandler {
    
    typealias OutboundIn = HTTPServerRequest
    typealias OutboundOut = FastCGIRecord
    
    var requestID: UInt16 = 0
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let httpRequest = unwrapOutboundIn(data)
        var params: [[String : String]] = [[:]]
        requestID = requestID + 1
        for header in httpRequest.headers{
            params.append(["name" : "HTTP_" + header.key.uppercased().replacingOccurrences(of: "-", with: "_"), "value" : header.value.joined(separator: ",")])
        }
        
        params.append(["name" : "REQUEST_METHOD", "value" : httpRequest.method.uppercased()])
        params.append(["name": "REMOTE_ADDR", "value" : httpRequest.remoteAddress])
        params.append(["name": "REMOTE_PORT", "value": String(httpRequest.urlURL.port!)])
        params.append(["name": "SCRIPT_NAME", "value": httpRequest.urlURL.lastPathComponent])
        params.append(["name": "DOCUMENT_URI","value": httpRequest.urlURL.lastPathComponent])
        params.append(["name": "REQUEST_SCHEME", "value": httpRequest.urlURL.scheme!])
        params.append(["value": "times=9", "name": httpRequest.urlURL.query ?? ""])
        params.append(["name": "REQUEST_URI", "value": httpRequest.urlURL.lastPathComponent + (httpRequest.urlURL.query ?? "")])
        params.append(["name": "SERVER_PROTOCOL", "value": "HTTP/"+String(httpRequest.httpVersionMajor!)+String(httpRequest.httpVersionMinor!)])
        params.append(["name": "SERVER_ADDR", "value": "127.0.0.1"])
        params.append(["name": "SERVER_PORT", "value": "8080"])
        params.append(["name": "SERVER_NAME", "value": "localhost"])
        params.append(["name": "CONTENT_LENGTH", "value": "0"])
        params.append(["name": "CONTENT_TYPE", "value": ""])
        params.append(["name": "REDIRECT_STATUS", "value": "200"])
        params.append(["name": "SERVER_SOFTWARE", "value": "Kitura"])
        params.append(["name": "GATEWAY_INTERFACE", "value": "CGI/1.1"])
        
        let record1 = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION, type: .beginRequest, requestId: FastCGI.Constants.FASTCGI_DEFAULT_REQUEST_ID, contentData: .role(1))
        let record2 = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION, type: .params, requestId: FastCGI.Constants.FASTCGI_DEFAULT_REQUEST_ID, contentData: .params(params))
        let record3 = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION, type: .params, requestId: FastCGI.Constants.FASTCGI_DEFAULT_REQUEST_ID, contentData: .params([]))
        let record4 = FastCGIRecord(version: FastCGI.Constants.FASTCGI_PROTOCOL_VERSION, type: .stdin, requestId: FastCGI.Constants.FASTCGI_DEFAULT_REQUEST_ID, contentData: .data(Data("".utf8)))
        context.write(self.wrapOutboundOut(record1))
        context.write(self.wrapOutboundOut(record2))
        context.write(self.wrapOutboundOut(record3))
        context.writeAndFlush(self.wrapOutboundOut(record4))
    }
}
