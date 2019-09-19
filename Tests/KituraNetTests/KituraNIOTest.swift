/**
 * Copyright IBM Corporation 2016
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
 **/

import XCTest

@testable import KituraNet

import Foundation
import Dispatch
import SSLService

struct KituraNetTestError: Swift.Error {
    let message: String
}

class KituraNetTest: XCTestCase {

    static let useSSLDefault = true
    static let portDefault = 8080
    static let portReuseDefault = false

    var useSSL = useSSLDefault
    var port = portDefault

    var unixDomainSocketPath: String? = nil

    var socketFilePath = ""

    var socketType: SocketType = .tcp

    static let sslConfig: SSLService.Configuration = {
        let sslConfigDir = URL(fileURLWithPath: #file).appendingPathComponent("../SSLConfig")

        #if os(macOS)
            let certificatePath = sslConfigDir.appendingPathComponent("certificate.pem").standardized.path
            let keyPath = sslConfigDir.appendingPathComponent("key.pem").standardized.path
            return SSLService.Configuration(withCACertificateDirectory: nil, usingCertificateFile: certificatePath,
                                            withKeyFile: keyPath, usingSelfSignedCerts: true, cipherSuite: nil)

        #else
            let chainFilePath = sslConfigDir.appendingPathComponent("certificateChain.pfx").standardized.path
            return SSLService.Configuration(withChainFilePath: chainFilePath, withPassword: "kitura",
                                            usingSelfSignedCerts: true, cipherSuite: nil)
        #endif
    }()

    static let clientSSLConfig = SSLService.Configuration(withCipherSuite: nil, clientAllowsSelfSignedCertificates: true)

    func doSetUp() {
        // set up the unix socket file
#if os(Linux)
        let temporaryDirectory = "/tmp"
#else
        var temporaryDirectory: String
        if #available(OSX 10.12, *) {
            temporaryDirectory = FileManager.default.temporaryDirectory.path
        } else {
            temporaryDirectory = "/tmp"
        }
#endif
        self.socketFilePath = temporaryDirectory + "/" + String(ProcessInfo.processInfo.globallyUniqueString.prefix(20))
    }

    func doTearDown() {
        guard self.socketType != .tcp else { return }
        let fileURL = URL(fileURLWithPath: socketFilePath)
        let fm = FileManager.default
        do {
            try fm.removeItem(at: fileURL)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func startServer(_ delegate: ServerDelegate?, unixDomainSocketPath: String? = nil, port: Int = portDefault, useSSL: Bool = useSSLDefault, allowPortReuse: Bool = portReuseDefault, serverConfig: ServerOptions = ServerOptions()) throws -> HTTPServer {
        let serverConfig = serverConfig
        let server = HTTP.createServer()
        server.options = serverConfig
        server.delegate = delegate
        if useSSL {
            server.sslConfig = KituraNetTest.sslConfig
        }
        if let unixDomainSocketPath = unixDomainSocketPath {
            try server.listen(unixDomainSocketPath: unixDomainSocketPath)
        } else {
            server.allowPortReuse = allowPortReuse
            try server.listen(on: port, address: "localhost")
        }
        return server
    }

    /// Convenience function for starting an HTTPServer on an ephemeral port,
    /// returning the a tuple containing the server and the port it is listening on.
    func startEphemeralServer(_ delegate: ServerDelegate?, useSSL: Bool = useSSLDefault, allowPortReuse: Bool = portReuseDefault, serverConfig: ServerOptions = ServerOptions()) throws -> (server: HTTPServer, port: Int) {
        let serverConfig = serverConfig
        let server = try startServer(delegate, port: 0, useSSL: useSSL,allowPortReuse: allowPortReuse, serverConfig: serverConfig)
        guard let serverPort = server.port else {
            throw KituraNetTestError(message: "Server port was not initialized")
        }
        guard serverPort != 0 else {
            throw KituraNetTestError(message: "Ephemeral server port not set (was zero)")
        }
        return (server, serverPort)
    }


    enum SocketType {
        case tcp
        case unixDomainSocket
        case both
    }

    func performServerTest(serverConfig: ServerOptions = ServerOptions(), _ delegate: ServerDelegate?, socketType: SocketType = .both, useSSL: Bool = useSSLDefault, allowPortReuse: Bool = portReuseDefault, line: Int = #line, asyncTasks: (XCTestExpectation) -> Void...) {
        let serverConfig = serverConfig
        self.socketType = socketType
        if socketType != .tcp {
            performServerTestWithUnixSocket(serverConfig: serverConfig, delegate: delegate, useSSL: useSSL, allowPortReuse: allowPortReuse, line: line, asyncTasks: asyncTasks)
        }
        if socketType != .unixDomainSocket {
            performServerTestWithTCPPort(serverConfig: serverConfig ,delegate: delegate, useSSL: useSSL, allowPortReuse:  allowPortReuse, line: line, asyncTasks: asyncTasks)
        }
    }

    func performServerTestWithUnixSocket(serverConfig: ServerOptions = ServerOptions(), delegate: ServerDelegate?, useSSL: Bool = useSSLDefault, allowPortReuse: Bool = portReuseDefault, line: Int = #line, asyncTasks: [(XCTestExpectation) -> Void]) {
        do {
            var serverConfig = serverConfig
            var server: HTTPServer
            self.useSSL = useSSL
            self.unixDomainSocketPath = self.socketFilePath
            server = try startServer(delegate, unixDomainSocketPath: self.unixDomainSocketPath, useSSL: useSSL, allowPortReuse: allowPortReuse, serverConfig: serverConfig)
            defer {
                server.stop()
            }

            let requestQueue = DispatchQueue(label: "Request queue")
            for (index, asyncTask) in asyncTasks.enumerated() {
                let expectation = self.expectation(line: line, index: index)
                requestQueue.async {
                    asyncTask(expectation)
                }
            }

            // wait for timeout or for all created expectations to be fulfilled
            waitExpectation(timeout: 10) { error in
                XCTAssertNil(error)
            }
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func performServerTestWithTCPPort(serverConfig: ServerOptions = ServerOptions(), delegate: ServerDelegate?, useSSL: Bool = useSSLDefault, allowPortReuse: Bool = portReuseDefault, line: Int = #line, asyncTasks: [(XCTestExpectation) -> Void]) {
        do {
            var serverConfig = serverConfig
            var server: HTTPServer
            var ephemeralPort: Int = 0
            self.useSSL = useSSL
            (server, ephemeralPort) = try startEphemeralServer(delegate, useSSL: useSSL, allowPortReuse: allowPortReuse,serverConfig: serverConfig)
            self.port = ephemeralPort
            self.unixDomainSocketPath = nil
            defer {
                server.stop()
            }
            let requestQueue = DispatchQueue(label: "Request queue")
            for (index, asyncTask) in asyncTasks.enumerated() {
                let expectation = self.expectation(line: line, index: index)
                requestQueue.async {
                    asyncTask(expectation)
                }
            }

            // wait for timeout or for all created expectations to be fulfilled
            waitExpectation(timeout: 10) { error in
                XCTAssertNil(error)
            }
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    /*func performFastCGIServerTest(_ delegate: ServerDelegate?, port: Int = portDefault, allowPortReuse: Bool = portReuseDefault,
                                  line: Int = #line, asyncTasks: (XCTestExpectation) -> Void...) {

        do {
            self.port = port

            let server = try FastCGIServer.listen(on: port, delegate: delegate)
            server.allowPortReuse = allowPortReuse
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
        }
        catch {
            XCTFail("Error: \(error)")
        }
    }*/

    func performRequest(_ method: String, path: String, hostname: String = "localhost", close: Bool=true, callback: @escaping ClientRequest.Callback,
                        headers: [String: String]? = nil, requestModifier: ((ClientRequest) -> Void)? = nil) {

        var allHeaders = [String: String]()
        if  let headers = headers {
            for  (headerName, headerValue) in headers {
                allHeaders[headerName] = headerValue
            }
        }
        allHeaders["Content-Type"] = "text/plain"

        let schema = self.useSSL ? "https" : "http"
        var options: [ClientRequest.Options] = [.method(method), .schema(schema), .hostname(hostname), .path(path), .headers(allHeaders)]
        if self.useSSL {
            options.append(.disableSSLVerification)
        }

        let req: ClientRequest
        if let unixDomainSocketPath = self.unixDomainSocketPath {
            req = HTTP.request(options, unixDomainSocketPath: unixDomainSocketPath, callback: callback)
        } else {
            options.append(.port(UInt16(self.port).toInt16()))
            req = HTTP.request(options, callback: callback)
        }
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

private extension UInt16 {
    func toInt16() -> Int16 {
        return Int16(bitPattern: self)
    }
}
