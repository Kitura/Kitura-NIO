import XCTest
@testable import KituraNIO

class BufferListTests: XCTestCase {
    var bufferList = BufferList()

    func testAppendUnsafePointerLength() {
       let array: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
       let pointer: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: array)
       bufferList.append(bytes: pointer, length: 10)
       bufferList.reset()
    }

    func testAppendData() {
        let data = Data(repeating: 0, count: 1024)
        bufferList.append(data: data)
        var fillData = Data(capacity: 2048)
        let result = bufferList.fill(data: &fillData)
        XCTAssertEqual(result, 1024)
        bufferList.append(data: data)
        bufferList.append(data: data)
        let result0 = bufferList.fill(data: &fillData)
        XCTAssertEqual(result0, 2048)
        bufferList.reset()
    }

    func testFillArray() {
        let data = Data(repeating: 1, count: 1024)
        bufferList.append(data: data)
        var fillArray = [UInt8](repeating: 0, count: 512)
        let result = bufferList.fill(array: &fillArray)
        XCTAssertEqual(result, 512)
        XCTAssertEqual(fillArray.reduce(0) { Int($0) + Int($1) }, 512)
        var fillArray0 = [UInt8](repeating: 0, count: 1024)
        let result0 = bufferList.fill(array: &fillArray0)
        XCTAssertEqual(result0, 512)        
        bufferList.reset()
    }

    func testFillData() {
        let data = Data(repeating: 1, count: 512)
        bufferList.append(data: data)
        var fillData = Data(capacity: 400)
        let result = bufferList.fill(data: &fillData)
        XCTAssertEqual(result, 512)
        XCTAssertEqual(fillData.reduce(0) { Int($0) + Int($1) }, 512)
        bufferList.reset()
    }

    func testFillMutableData() {
        let data = Data(repeating: 1, count: 512)
        bufferList.append(data: data)
        let fillData = NSMutableData(capacity: 400)!
        let result = bufferList.fill(data: fillData)
        XCTAssertEqual(result, 400)
        bufferList.reset()
    }


    func testFillUnsafeMutablePointer() {
        let data = Data(repeating: 1, count: 512)
        bufferList.append(data: data)
        let array = [UInt8](repeating: 0, count: 64)
        let pointer = UnsafeMutablePointer(mutating: array)
        let result = bufferList.fill(buffer: pointer, length: 64) 
        XCTAssertEqual(result, 64)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: pointer, count: 64)).reduce(0) { Int($0) + Int($1) }, 64)
        bufferList.reset()
    }

    func testRewind() {
        let data = Data(repeating: 1, count: 64)
        bufferList.append(data: data)
        var array0 = [UInt8](repeating: 0, count: 48)
        let result0 = bufferList.fill(array: &array0)
        XCTAssertEqual(result0, 48)
        bufferList.rewind()
        var array1 = [UInt8](repeating: 0, count: 48)
        let result1 = bufferList.fill(array: &array1) 
        XCTAssertEqual(result1, 48)
        bufferList.reset()
    }

    func testDataAndCount() {
        let data = Data(repeating: 1, count: 64)
        bufferList.append(data: data) 
        XCTAssertEqual(bufferList.data.count, 64)
        XCTAssertEqual(bufferList.count, 4096)
        bufferList.reset()
    }
        
    static var allTests = [
        ("testAppendUnsafePointerLength", testAppendUnsafePointerLength),
        ("testAppendData", testAppendData),
        ("testFillArray", testFillArray),
        ("testFillData", testFillData), 
        ("testFillUnsafeMutablePointer", testFillUnsafeMutablePointer),
        ("testRewind", testRewind),
        ("testDataAndCount", testDataAndCount),
    ]
}
