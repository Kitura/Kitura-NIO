import XCTest
import SSLService
import Dispatch
@testable import KituraNIO

class KituraNIOTest: XCTestCase {

    static let useSSLDefault = true
    static let httpPort = 8080
    static let portReuseDefault = false

    static let sslConfig: SSLService.Configuration = {
        let sslConfigDir = URL(fileURLWithPath: #file).appendingPathComponent("../SSLConfig/")
        #if os(Linux)
            let certificatePath = sslConfigDir.appendingPathComponent("certificate.pem").standardized.path
            let keyPath = sslConfigDir.appendingPathComponent("key.pem").standardized.path
            return  SSLService.Configuration(withCACertificateFilePath: nil, usingCertificateFile: certificatePath, withKeyFile:keyPath)
        #else
            let chainFilePath = sslConfigDir.appendingPathComponent("certificateChain.pfx").standardized.path
            return SSLConfig(withChainFilePath: chainFilePath, withPassword: "kitura", usingSelfSignedCerts: true)
        #endif
    }()

    var useSSL = useSSLDefault
    var port = httpPort

    func performServerTest(_ delegate: ServerDelegate?, port: Int = httpPort, useSSL: Bool = useSSLDefault, allowPortReuse: Bool = portReuseDefault, line: Int = #line, asyncTasks: (XCTestExpectation) -> Void...) {

        do {
            self.useSSL = useSSL

            self.port = port

            let server: HTTPServer = try startServer(delegate, port: port, useSSL: useSSL, allowPortReuse: allowPortReuse)
            defer {
                server.stop()
            }

            let requestQueue = DispatchQueue(label: "Request queue")
            for (index, asyncTask) in asyncTasks.enumerated() {
                let expectation = self.expectation(line: line, index: index)
                requestQueue.async() {
                    asyncTask(expectation)
                }
            }

            // wait for timeout or for all created expectations to be fulfilled
            waitExpectation(timeout: 10) { error in
                XCTAssertNil(error);
            }
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func startServer(_ delegate: ServerDelegate?, port: Int = httpPort, useSSL: Bool = false, allowPortReuse: Bool = portReuseDefault) throws -> HTTPServer {
        
        let server = HTTP.createServer()
        server.delegate = delegate
        server.allowPortReuse = allowPortReuse
        if useSSL {
            server.sslConfig = KituraNIOTest.sslConfig
        }
        try server.listen(on: port)
        return server
    }
    
    func performRequest(_ method: String, path: String, hostname: String, close: Bool=true, callback: @escaping ClientRequest.Callback,
                        headers: [String: String]? = nil, requestModifier: ((ClientRequest) -> Void)? = nil) {
        
        var allHeaders = [String: String]()
        if  let headers = headers  {
            for  (headerName, headerValue) in headers  {
                allHeaders[headerName] = headerValue
            }
        }
        allHeaders["Content-Type"] = "text/plain"
        
        let schema = self.useSSL ? "https" : "http"
        var options: [ClientRequest.Options] =
            [.method(method), .schema(schema), .hostname(hostname), .port(Int16(self.port)), .path(path), .headers(allHeaders)]
        if self.useSSL {
            options.append(.disableSSLVerification)
        }
        
        let req = HTTP.request(options, callback: callback)
        if let requestModifier = requestModifier {
            requestModifier(req)
        }
        req.end(close: close)
    }

    func expectation(line: Int, index: Int) -> XCTestExpectation {
        return self.expectation(description: "\(type(of: self)):\(line)[\(index)]")
    }

    func waitExpectation(timeout: TimeInterval, handler: XCWaitCompletionHandler?) {
        self.waitForExpectations(timeout: timeout, handler: handler)
    }
}
