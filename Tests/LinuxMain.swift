import XCTest
@testable import KituraNIOTests

// http://stackoverflow.com/questions/24026510/how-do-i-shuffle-an-array-in-swift
extension MutableCollection {
    mutating func shuffle() {
        let c = count
        guard c > 1 else { return }

        srand(UInt32(time(nil)))
        for (firstUnshuffled , unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
            let d: IndexDistance = numericCast(random() % numericCast(unshuffledCount))
            guard d != 0 else { continue }
            let i = index(firstUnshuffled, offsetBy: d)
            swapAt(firstUnshuffled, i)
        }
    }
}

extension Sequence {
    func shuffled() -> [Iterator.Element] {
        var result = Array(self)
        result.shuffle()
        return result
    }
}

XCTMain([
    testCase(IPv6Tests.allTests.shuffled()),
    testCase(BufferListTests.allTests.shuffled()),
    testCase(ClientRequestTests.allTests.shuffled()),
    testCase(HTTPResponseTests.allTests.shuffled()),
    testCase(HTTPStatusCodeTests.allTests.shuffled()),
    testCase(LargePayloadTests.allTests.shuffled()),
    testCase(LifecycleListenerTests.allTests.shuffled()),
    testCase(MiscellaneousTests.allTests.shuffled()),
    testCase(ParserTests.allTests.shuffled()),
    testCase(ClientE2ETests.allTests.shuffled()),
    testCase(PipeliningTests.allTests.shuffled()),
    testCase(RegressionTests.allTests.shuffled()),
].shuffled())
