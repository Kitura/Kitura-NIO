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

import XCTest

@testable import KituraNet

class UnixDomainSocketTests: KituraNetTest {

    static var allTests: [(String, (UnixDomainSocketTests) -> () throws -> Void)] {
        return [
            ("testPostRequestWithUnixDomainSocket", testPostRequestWithUnixDomainSocket),
        ]
    }

    override func setUp() {
        doSetUp()

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

    override func tearDown() {
        doTearDown()
        let fileURL = URL(fileURLWithPath: socketFilePath)
        let fm = FileManager.default
        do {
            try fm.removeItem(at: fileURL)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    private var socketFilePath = ""
    private let delegate = TestServerDelegate()

    func testPostRequestWithUnixDomainSocket() {
        performServerTest(delegate, unixDomainSocketPath: socketFilePath, useSSL: false, asyncTasks: { expectation in
            let payload = "[" + contentTypesString + "," + contentTypesString + "]"
            self.performRequest("post", path: "/uds", unixDomainSocketPath: self.socketFilePath, callback: {response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    let expected = "Read \(payload.count) bytes"
                    var data = Data()
                    let count = try response?.readAllData(into: &data)
                    XCTAssertEqual(count, expected.count, "Result should have been \(expected.count) bytes, was \(String(describing: count)) bytes")
                    let postValue = String(data: data, encoding: .utf8)
                    if  let postValue = postValue {
                        XCTAssertEqual(postValue, expected)
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

    private class TestServerDelegate: ServerDelegate {
        func handle(request: ServerRequest, response: ServerResponse) {
            var body = Data()
            do {
                let length = try request.readAllData(into: &body)
                let result = "Read \(length) bytes"
                response.headers["Content-Type"] = ["text/plain"]
                response.headers["Content-Length"] = ["\(result.count)"]

                try response.end(text: result)
            } catch {
                print("Error reading body or writing response")
            }
        }
    }
}
