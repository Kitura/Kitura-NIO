import XCTest
@testable import KituraNIOTests

XCTMain([
    testCase(KituraNIOTests.allTests),
    testCase(IPv6Tests.allTests),
])
