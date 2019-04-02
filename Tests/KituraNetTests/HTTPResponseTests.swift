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

class HTTPResponseTests: KituraNetTest {
    static var allTests: [(String, (HTTPResponseTests) -> () throws -> Void)] {
        return [
            ("testContentTypeHeaders", testContentTypeHeaders),
            ("testHeadersContainerHTTPHeaders", testHeadersContainerHTTPHeaders),
            ("testMultipleWritesToResponse", testMultipleWritesToResponse)
        ]
    }

    override func setUp() {
        doSetUp()
    }

    override func tearDown() {
        doTearDown()
    }

    func testContentTypeHeaders() {
        let headers = HeadersContainer()

        headers.append("Content-Type", value: "text/html")
        var values = headers["Content-Type"]
        XCTAssertNotNil(values, "Couldn't retrieve just set Content-Type header")
        XCTAssertEqual(values?.count, 1, "Content-Type header should only have one value")
        XCTAssertEqual(values?[0], "text/html")

        headers.append("Content-Type", value: "text/plain; charset=utf-8")
        XCTAssertEqual(headers["Content-Type"]?[0], "text/html")

        headers["Content-Type"] = nil
        XCTAssertNil(headers["Content-Type"])

        headers.append("Content-Type", value: "text/plain, image/png")
        XCTAssertEqual(headers["Content-Type"]?[0], "text/plain, image/png")

        headers.append("Content-Type", value: "text/html, image/jpeg")
        XCTAssertEqual(headers["Content-Type"]?[0], "text/plain, image/png")

        headers.append("Content-Type", value: "charset=UTF-8")
        XCTAssertEqual(headers["Content-Type"]?[0], "text/plain, image/png")

        headers["Content-Type"] = nil

        headers.append("Content-Type", value: "text/html")
        XCTAssertEqual(headers["Content-Type"]?[0], "text/html")

        headers.append("Content-Type", value: "image/png, text/plain")
        XCTAssertEqual(headers["Content-Type"]?[0], "text/html")
    }

    func testHeadersContainerHTTPHeaders() {
        let headers = HeadersContainer()
        headers["Content-Type"] = ["image/png, text/plain"]
        XCTAssertEqual(headers.nioHeaders["Content-Type"], headers["Content-Type"]!)
        headers["Content-Type"] = ["text/html"]
        XCTAssertEqual(headers.nioHeaders["Content-Type"], headers["Content-Type"]!)
        headers["Content-Type"] = nil
        XCTAssertFalse(headers.nioHeaders.contains(name: "Content-Type"))
        headers["Set-Cookie"] = ["ID=123BAS; Path=/; Secure; HttpOnly"]
        headers.append("Set-Cookie", value: ["ID=KI9H12; Path=/; Secure; HttpOnly"])
        XCTAssertEqual(headers["Set-Cookie"]!, headers.nioHeaders["Set-Cookie"])
        headers["Content-Type"] = ["text/html"]
        headers.append("Content-Type", value: "text/json")
        XCTAssertEqual(headers.nioHeaders["Content-Type"], headers["Content-Type"]!)
        headers["foo"] = ["bar0"]
        headers.append("foo", value: "bar1")
        XCTAssertEqual(headers.nioHeaders["foo"], headers["foo"]!)
        headers.append("foo", value: ["bar2", "bar3"])
        XCTAssertEqual(headers.nioHeaders["foo"], headers["foo"]!)
        headers.removeAll()
        XCTAssertFalse(headers.nioHeaders.contains(name: "foo"))
    }

    func testMultipleWritesToResponse() {
        performServerTest(WriteTwiceServerDelegate(), useSSL: false) { expectation in
            self.performRequest("get", path: "/writetwice", callback: { response in
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
                do {
                    var data = Data()
                    _ = try response?.readAllData(into: &data)
                    let receivedString = String(data: data as Data, encoding: .utf8) ?? ""
                    XCTAssertEqual("Hello, World!", receivedString, "The string received \(receivedString) is not Hello, World!")
                } catch {
                    XCTFail("Error: \(error)")
                }
                expectation.fulfill()
            })
        }
    }
}

class WriteTwiceServerDelegate: ServerDelegate {
    func handle(request: ServerRequest, response: ServerResponse) {
        do {
            response.statusCode = .OK
            response.headers["Content-Type"] = ["text/plain"]
            let helloData = "Hello, ".data(using: .utf8)!
            let worldData = "World!".data(using: .utf8)!
            response.headers["Content-Length"] = ["13"]
            try response.write(from: helloData)
            try response.write(from: worldData)
            try response.end()
        } catch {
            print("Could not send a response")
        }
    }
}
