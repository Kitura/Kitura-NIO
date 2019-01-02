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

class MiscellaneousTests: KituraNetTest {

    static var allTests: [(String, (MiscellaneousTests) -> () throws -> Void)] {
        return [
            ("testEscape", testEscape),
            ("testHeadersContainers", testHeadersContainers),
            ("testHeadersContainerDualMode", testHeadersContainerDualMode),
        ]
    }

    func testEscape() {
        let testString = "#%?"
        let desiredResult = "%23%25%3F"

        XCTAssertEqual(HTTP.escape(url: testString), desiredResult, "Escape of \"\(testString)\" wasn't \"\(desiredResult)\", it was \"\(HTTP.escape(url: testString))\"")
    }

    func testHeadersContainers() {
        let headers = HeadersContainer()
        headers.append("Set-Cookie", value: "plover=xyzzy")
        headers.append("Set-Cookie", value: "kitura=great")
        headers.append("Content-Type", value: "text/plain")

        var foundSetCookie = false
        var foundContentType = false

        for (key, value) in headers {
            switch key.lowercased() {
            case "content-type":
                XCTAssertEqual(value.count, 1, "Content-Type didn't have only one value. It had \(value.count) values")
                XCTAssertEqual(value[0], "text/plain", "Expecting a value of text/plain. Found \(value[0])")
                foundContentType = true

            case "set-cookie":
                XCTAssertEqual(value.count, 2, "Set-Cookie didn't have two values. It had \(value.count) values")
                foundSetCookie = true

            default:
                XCTFail("Found a header other than Content-Type or Set-Cookie (\(key))")
            }
        }
        XCTAssert(foundContentType, "Didn't find the Content-Type header")
        XCTAssert(foundSetCookie, "Didn't find the Set-Cookie header")
    }

    func testHeadersContainerDualMode() {
        let headers = HeadersContainer()
        headers.append("Foo", value: "Bar")
        headers.append("Foo", value: "Baz")
        let numValues = headers["Foo"]?.count ?? 0
        XCTAssertEqual(numValues, 1, "Foo didn't have one value, as expected. It had \(numValues) values")

        let numValues1 = headers[headers.startIndex].value.count
        XCTAssertEqual(numValues1, 1, "Foo didn't have one value, as expected. It had \(numValues1) values")

        // Special case: cookies
        let cookieHeaders = HeadersContainer()
        cookieHeaders.append("Set-Cookie", value: "os=Linux")
        cookieHeaders.append("Set-Cookie", value: "browser=Safari")
        let numValues2 = cookieHeaders["Set-Cookie"]?.count ?? 0
        XCTAssertEqual(numValues2, 2, "Set-Cookie didn't have two values, as expected. It had \(numValues2) values")

        let numValues3 =  cookieHeaders[cookieHeaders.startIndex].value.count
        XCTAssertEqual(numValues3, 2, "Set-Cookie didn't have two values, as expected. It had \(numValues3) values")

        // Special case: Content-Type
        let contentHeaders = HeadersContainer()
        contentHeaders.append("Content-Type", value: "application/json")
        contentHeaders.append("Content-Type", value: "application/xml")
        let numValues4 = contentHeaders["Content-Type"]?.count ?? 0
        XCTAssertEqual(numValues4, 1, "Content-Type didn't have one value, as expected. It had \(numValues4) values")
        XCTAssertEqual(contentHeaders["Content-Type"]?.first!, "application/json")

        let numValues5 = contentHeaders[contentHeaders.startIndex].value.count
        XCTAssertEqual(numValues5, 1, "Content-Type didn't have one value, as expected. It had \(numValues5) values")

        // Append arrays
        headers.append("Foo", value: ["Cons", "Damn"])
        let numValues6 = headers["Foo"]?.count ?? 0
        XCTAssertEqual(numValues6, 1, "Foo didn't have one value, as expected. It had \(numValues6) values")

        cookieHeaders.append("Set-Cookie", value: ["abx=xyz", "def=fgh"])
        let numValues7 = cookieHeaders["Set-Cookie"]?.count ?? 0
        XCTAssertEqual(numValues7, 4, "Set-Cookie didn't have four values, as expected. It had \(numValues7) values")

        // Append arrays to a new container
        let headers1 = HeadersContainer()
        headers1.append("Foo", value: "Bar")
        headers1.append("Foo", value: ["Cons", "Damn"])
        let numValues8 = headers1[headers1.startIndex].value.count
        XCTAssertEqual(numValues8, 1, "Foo didn't have one value, as expected. It had \(numValues8) values")

        let cookieHeaders1 = HeadersContainer()
        cookieHeaders1.append("Set-Cookie", value: "os=Linux")
        cookieHeaders1.append("Set-Cookie", value: ["browser=Safari", "temp=xyz"])
        let numValues9 = cookieHeaders1[cookieHeaders1.startIndex].value.count
        XCTAssertEqual(numValues9, 3, "Set-Cookie didn't have three values, as expected. It had \(numValues9) values")

        // Set using subscript function before and after mode switch
        let headers2 = HeadersContainer()
        headers2.append("Foo", value: "Bar")
        headers2["Foo"] = ["Baz"]
        XCTAssertNotNil(headers2["Foo"])
        XCTAssertEqual(headers2["Foo"]!.count, 1)
        XCTAssertEqual(headers2["Foo"]!.first!, "Baz")

        let numValues10 = headers2[headers2.startIndex].value.count
        XCTAssertEqual(numValues10, 1)
        headers2["Foo"] = ["Bar", "Baz"]
        XCTAssertEqual(headers2["Foo"]!.count, 2)
        XCTAssertEqual(headers2["Foo"]!.first!, "Bar")

        let cookieHeaders2 = HeadersContainer()
        cookieHeaders2.append("Set-Cookie", value: "os=Linux")
        cookieHeaders2["Set-Cookie"] = ["browser=Safari", "temp=xyz"]
        let numValues11 = cookieHeaders2[cookieHeaders2.startIndex].value.count
        XCTAssertEqual(numValues11, 2, "Set-Cookie didn't have two values, as expected. It had \(numValues11) values")

        // removeAll
        headers2.removeAll()
        cookieHeaders2.removeAll()

        for _ in headers2 {
            XCTFail("Headers2 must be empty!")
        }

        for _ in cookieHeaders2 {
            XCTFail("cookieHeaders2 must be empty!")
        }
    }
}
