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

import Foundation
import Dispatch

import XCTest

@testable import KituraNet

class ClientE2ETests: KituraNetTest {

    static var allTests: [(String, (ClientE2ETests) -> () throws -> Void)] {
        return [
            ("testEphemeralListeningPort", testEphemeralListeningPort),
            ("testErrorRequests", testErrorRequests),
            ("testHeadRequests", testHeadRequests),
            ("testKeepAlive", testKeepAlive),
            ("testPostRequests", testPostRequests),
            ("testPutRequests", testPutRequests),
            ("testPatchRequests", testPatchRequests),
            ("testSimpleHTTPClient", testSimpleHTTPClient),
            ("testUrlURL", testUrlURL),
            ("testQueryParameters", testQueryParameters),
            ("testRedirect", testRedirect),
            ("testPercentEncodedQuery", testPercentEncodedQuery),
            ("testRequestSize",testRequestSize),
        ]
    }

    override func setUp() {
        doSetUp()
    }

    override func tearDown() {
        doTearDown()
    }

    static let urlPath = "/urltest"

    let delegate = TestServerDelegate()

    func testRequestSize() {
        performServerTest(serverConfig: ServerOptions(requestSizeLimit: 10000, connectionLimit: 100),delegate, useSSL: false, asyncTasks: { expectation in
            let payload = "[" + contentTypesString + "," + contentTypesString + contentTypesString + "," + contentTypesString + "]"
            self.performRequest("post", path: "/largepost", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.requestTooLong)
                do {
                    let expectedResult = ""
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, expectedResult.count, "Result should have been \(expectedResult.count) bytes, was \(String(describing: count)) bytes")
                    let postValue = String(data: data, encoding: .utf8)
                    if  let postValue = postValue {
                        XCTAssertEqual(postValue, expectedResult)
                    } else {
                        XCTFail("postValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            }) {request in
                request.write(from: payload)
            }
        })
    }

    func testHeadRequests() {
        performServerTest(delegate) { expectation in
            self.performRequest("head", path: "/headtest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, 0, "Result should have been zero bytes, was \(String(describing: count)) bytes")
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                XCTAssertEqual(response?.httpVersionMajor, 1, "HTTP Major code from KituraNet should be 1, was \(String(describing: response?.httpVersionMajor))")
                XCTAssertEqual(response?.httpVersionMinor, 1, "HTTP Minor code from KituraNet should be 1, was \(String(describing: response?.httpVersionMinor))")
                expectation.fulfill()
            })
        }
    }

    func testKeepAlive() {
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("get", path: "/posttest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .OK was \(String(describing: response?.statusCode))")
                if let connectionHeader = response?.headers["Connection"] {
                    XCTAssertEqual(connectionHeader.count, 1, "The Connection header didn't have only one value. Value=\(connectionHeader)")
                    XCTAssertEqual(connectionHeader[0], "Close", "The Connection header didn't have a value of 'Close' (was \(connectionHeader[0]))")
                }
                expectation.fulfill()
            })
        }, { expectation in
            self.performRequest("get", path: "/posttest", close: false, callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .OK was \(String(describing: response?.statusCode))")
                if let connectionHeader = response?.headers["Connection"] {
                    XCTAssertEqual(connectionHeader.count, 1, "The Connection header didn't have only one value. Value=\(connectionHeader)")
                    XCTAssertEqual(connectionHeader[0], "Keep-Alive", "The Connection header didn't have a value of 'Keep-Alive' (was \(connectionHeader[0]))")
                }
                expectation.fulfill()
            })
        })
    }

    func testEphemeralListeningPort() {
        do {
            let server = try HTTPServer.listen(on: 0, address: "localhost", delegate: delegate)
            _ = HTTP.get("http://localhost:\(server.port!)") { response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response?.statusCode))")
            }
            server.stop()
        } catch let error {
            XCTFail("Error: \(error)")
        }
    }

    func testSimpleHTTPClient() {
        let delegate = TestSimpleClientDelegate()
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("get", path: "/" , callback: { response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .OK was \(String(describing: response?.statusCode))")
                if let contentType = response?.headers["Content-type"] {
                    XCTAssertEqual(contentType, ["text/plain"], "Content-Type wasn't text/plain")
                }

                do {
                    let result = try response?.readString()
                    XCTAssertNotNil(result, "The body of the response was empty")
                    XCTAssertEqual(result?.count, 13, "Result should have been 13 bytes, was \(String(describing: result?.count))")
                    XCTAssertEqual(result, "Hello, World!")
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
        })
    }

    func testPostRequests() {
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("post", path: "/posttest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    let postValue = try response?.readString()
                    XCTAssertNotNil(postValue, "The body of the response was empty")
                    XCTAssertEqual(postValue?.count, 12, "Result should have been 12 bytes, was \(String(describing: postValue?.count)) bytes")
                    if  let postValue = postValue {
                        XCTAssertEqual(postValue, "Read 0 bytes")
                    } else {
                        XCTFail("postValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
        }, { expectation in
            self.performRequest("post", path: "/posttest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, 13, "Result should have been 13 bytes, was \(String(describing: count)) bytes")
                    let postValue = String(data: data as Data, encoding: .utf8)
                    if  let postValue = postValue {
                        XCTAssertEqual(postValue, "Read 16 bytes")
                    } else {
                        XCTFail("postValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            }) { request in
                request.set(.disableSSLVerification)
                request.write(from: "A few characters")
            }
        })
    }

    func testPutRequests() {
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("put", path: "/puttest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, 12, "Result should have been 12 bytes, was \(String(describing: count)) bytes")
                    let putValue = String(data: data as Data, encoding: .utf8)
                    if  let putValue = putValue {
                        XCTAssertEqual(putValue, "Read 0 bytes")
                    } else {
                        XCTFail("putValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
        }, { expectation in
            self.performRequest("put", path: "/puttest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, 13, "Result should have been 13 bytes, was \(String(describing: count)) bytes")
                    let postValue = String(data: data as Data, encoding: .utf8)
                    if  let postValue = postValue {
                        XCTAssertEqual(postValue, "Read 16 bytes")
                    } else {
                        XCTFail("postValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            }) {request in
                request.write(from: "A few characters")
            }
        })
    }

    func testPatchRequests() {
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("patch", path: "/patchtest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, 12, "Result should have been 12 bytes, was \(String(describing: count)) bytes")
                    let patchValue = String(data: data as Data, encoding: .utf8)
                    if  let patchValue = patchValue {
                        XCTAssertEqual(patchValue, "Read 0 bytes")
                    } else {
                        XCTFail("patchValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
        }, { expectation in
            self.performRequest("patch", path: "/patchtest", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, 13, "Result should have been 13 bytes, was \(String(describing: count)) bytes")
                    let patchValue = String(data: data as Data, encoding: .utf8)
                    if  let patchValue = patchValue {
                        XCTAssertEqual(patchValue, "Read 16 bytes")
                    } else {
                        XCTFail("patchValue's value wasn't an UTF8 string")
                    }
                } catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            }) {request in
                request.write(from: "A few characters")
            }
        })
    }

    func testErrorRequests() {
        performServerTest(delegate, asyncTasks: { expectation in
            self.performRequest("plover", path: "/xzzy", callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.badRequest, "Status code wasn't .badrequest was \(String(describing: response?.statusCode))")
                expectation.fulfill()
            })
        })
    }

    func testUrlURL() {
        let delegate = TestURLDelegate()
        performServerTest(delegate, socketType: .tcp) { expectation in
            delegate.port = self.port
            let headers = ["Host": "localhost:\(self.port)"]
            self.performRequest("post", path: ClientE2ETests.urlPath, callback: { response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                expectation.fulfill()
            }, headers: headers)
        }
    }

    func testQueryParameters() {
        class TestDelegate : ServerDelegate {
            func toDictionary(_ queryItems: [URLQueryItem]?) -> [String : String] {
                guard let queryItems = queryItems else { return [:] }
                var queryParameters: [String : String] = [:]
                for queryItem in queryItems {
                    queryParameters[queryItem.name] = queryItem.value ?? ""
                }
                return queryParameters
            }

            func handle(request: ServerRequest, response: ServerResponse) {
               do {
                   let urlComponents = URLComponents(url: request.urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
                   let queryParameters = toDictionary(urlComponents.queryItems)
                   XCTAssertEqual(queryParameters.count, 3, "Expected 3 query parameters, received \(queryParameters.count)")
                   XCTAssertEqual(queryParameters["key1"], "value1", "Value of key1 should have been value1, received \(queryParameters["key1"]!)")
                   XCTAssertEqual(queryParameters["key2"], "value2", "Value of key2 should have been value2, received \(queryParameters["key2"]!)")
                   XCTAssertEqual(queryParameters["key3"], "value3 value4", "Value of key3 should have been \"value3 value4\", received \(queryParameters["key3"]!)")
                   response.statusCode = .OK
                   try response.end()
                } catch {
                    XCTFail("Error while writing a response")
                }
            }
        }
        let testDelegate = TestDelegate()
        performServerTest(testDelegate) { expectation in
            self.performRequest("get", path: "/zxcv/p?key1=value1&key2=value2&key3=value3%20value4", callback: { response in
                XCTAssertEqual(response?.statusCode, .OK)
                expectation.fulfill()
            })
        }
    }

    func testRedirect() {
        class TestRedirectionDelegate: ServerDelegate {
            func handle(request: ServerRequest, response: ServerResponse) {
                switch request.urlURL.path {
                case "/redirecting":
                    response.statusCode = .movedPermanently
                    response.headers.append("Location", value: ["/redirected"])
                    do {
                        try response.end()
                    } catch {
                        XCTFail("Failed to send response")
                    }
                case "/redirected":
                    response.statusCode = .OK
                    do {
                        try response.end(text: "from redirected route")
                    } catch {
                        XCTFail("Failed to send response")
                    }
                default:
                    XCTFail("This request pertains to an unexpected path")
                }
            }
        }

        let redirectingDelegate = TestRedirectionDelegate()
        performServerTest(redirectingDelegate) { expectation in
            self.performRequest("get", path: "/redirecting", callback: { response in
                XCTAssertEqual(response?.statusCode, .OK, "Expected response code OK(200), but received \"(response?.statusCode)")
                let responseString = try! response?.readString() ?? ""
                XCTAssertEqual(responseString, "from redirected route", "Redirection failed")
                expectation.fulfill()
            })
        }
    }

    func testPercentEncodedQuery() {
        class TestDelegate: ServerDelegate {
            func handle(request: ServerRequest, response: ServerResponse) {
                do {
                   let urlComponents = URLComponents(url: request.urlURL, resolvingAgainstBaseURL: false) ?? URLComponents()
                   XCTAssertNotNil(urlComponents.queryItems)
                   for queryItem in urlComponents.queryItems! {
                       XCTAssertEqual(queryItem.name, "parameter", "Query name should have been parameter, received \(queryItem.name)")
                       XCTAssertEqual(queryItem.value, "Hi There", "Query value should have been Hi There, received \(queryItem.value ?? "")")
                    }
                    response.statusCode = .OK
                    try response.end()
                } catch {
                    XCTFail("Error while writing response")
                }   
            }
        }

        let delegate = TestDelegate()
        performServerTest(delegate) { expectation in
            self.performRequest("get", path: "/zxcv?parameter=Hi%20There", callback: { response in
                XCTAssertEqual(response?.statusCode, .OK, "Expected response code OK(200), but received \"(response?.statusCode)")
                expectation.fulfill()
            })
        }
    }

    class TestServerDelegate: ServerDelegate {
        let remoteAddress = ["127.0.0.1", "::1", "::ffff:127.0.0.1", "uds"]

        func handle(request: ServerRequest, response: ServerResponse) {
            XCTAssertTrue(remoteAddress.contains(request.remoteAddress), "Remote address wasn't ::1 or 127.0.0.1 or ::ffff:127.0.0.1, it was \(request.remoteAddress)")

            let result: String
            switch request.method.lowercased() {
            case "head":
                result = "This a really simple head request result"

            case "put":
                do {
                    let body = try request.readString()
                    result = "Read \(body?.count ?? 0) bytes"
                } catch {
                    print("Error reading body")
                    result = "Read -1 bytes"
                }

            default:
                var body = Data()
                do {
                    let length = try request.readAllData(into: &body)
                    result = "Read \(length) bytes"
                } catch {
                    print("Error reading body")
                    result = "Read -1 bytes"
                }
            }

            do {
                response.statusCode = .OK
                XCTAssertEqual(response.statusCode, .OK, "Set response status code wasn't .OK, it was \(String(describing: response.statusCode))")
                response.headers["Content-Type"] = ["text/plain"]
                response.headers["Content-Length"] = ["\(result.count)"]

                try response.end(text: result)
            } catch {
                print("Error writing response")
            }
        }
    }

    class TestURLDelegate: ServerDelegate {
        var port = 0

        func handle(request: ServerRequest, response: ServerResponse) {
            XCTAssertEqual(request.urlURL.host, "localhost")
            XCTAssertEqual(request.httpVersionMajor, 1, "HTTP Major code from KituraNet should be 1, was \(String(describing: request.httpVersionMajor))")
            XCTAssertEqual(request.httpVersionMinor, 1, "HTTP Minor code from KituraNet should be 1, was \(String(describing: request.httpVersionMinor))")
            XCTAssertEqual(request.urlURL.path, urlPath, "Path in request.urlURL wasn't \(urlPath), it was \(request.urlURL.path)")
            XCTAssertEqual(request.urlURL.port, self.port)
            XCTAssertEqual(request.url, urlPath.data(using: .utf8))
            do {
                response.statusCode = .OK
                let result = "OK"
                response.headers["Content-Type"] = ["text/plain"]
                let resultData = result.data(using: .utf8)!
                response.headers["Content-Length"] = ["\(resultData.count)"]

                try response.write(from: resultData)
                try response.end()
            } catch {
                print("Error reading body or writing response")
            }
        }
    }

    class TestSimpleClientDelegate: ServerDelegate {

        func handle(request: ServerRequest, response: ServerResponse) {
            do {
                let result: String = "Hello, World!"
                response.statusCode = .OK
                response.headers["Content-Type"] = ["text/plain"]
                response.headers["Content-Length"] = ["\(result.count)"]
                try response.end(text: result)
            } catch {
                XCTFail("Error while writing response")
            }
        }
    }
}
