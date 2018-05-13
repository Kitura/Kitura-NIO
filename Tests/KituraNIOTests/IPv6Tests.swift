/*
 * Copyright IBM Corporation 2018
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
 */

import XCTest
@testable import KituraNIO

class IPv6Tests: KituraNetTest {

    static var allTests = [
        ("testIPv4", testIPv4),
        ("testIPv4WithSSL", testIPv4WithSSL),
        ("testIPv6", testIPv6),
        ("testIPv6WithSSL", testIPv6WithSSL)
    ]

    let router = Router()

    func testIPv4() {
        performServerTest(router, useSSL: false, allowPortReuse: true) { expectation in
            self.performRequest("get", path: "/", hostname: "127.0.0.1", callback: {response in

                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertNotEqual(count, 0, "Result should have been zero bytes, was \(String(describing: count)) bytes")
                }
                catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
       }
    }

    func testIPv4WithSSL() {
        performServerTest(router, allowPortReuse: true) { expectation in
            self.performRequest("get", path: "/", hostname: "127.0.0.1", callback: {response in

                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertNotEqual(count, 0, "Result should have been zero bytes, was \(String(describing: count)) bytes")
                }
                catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
       }
    }

    func testIPv6() {
        performServerTest(router, useSSL: false, allowPortReuse: true, supportIPv6: true) { expectation in
            self.performRequest("get", path: "/", hostname: "localhost", callback: {response in

                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertNotEqual(count, 0, "Result should have been zero bytes, was \(String(describing: count)) bytes")
                }
                catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
       }
    }

    func testIPv6WithSSL() {
        performServerTest(router, allowPortReuse: true, supportIPv6: true) { expectation in
            self.performRequest("get", path: "/", hostname: "localhost", callback: {response in

                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertNotEqual(count, 0, "Result should have been zero bytes, was \(String(describing: count)) bytes")
                }
                catch {
                    XCTFail("Failed reading the body of the response")
                }
                expectation.fulfill()
            })
       }
    }


    class Router: ServerDelegate {

        func handle(request: ServerRequest, response: ServerResponse) {
            let result: String
            var body = Data()
            do {
                let length = try request.readAllData(into: &body)
                result = "Read \(length) bytes"
            }
            catch {
                print("Error reading body")
                result = "Read -1 bytes"
            }
 
            do {
                response.statusCode = .OK
                XCTAssertEqual(response.statusCode, .OK, "Set response status code wasn't .OK, it was \(String(describing: response.statusCode))")
                response.headers["Content-Type"] = ["text/plain"]
                response.headers["Content-Length"] = ["\(result.count)"]
   
                try response.end(text: result)
            }
            catch {
                print("Error writing response")
            }
        }
    }
}
