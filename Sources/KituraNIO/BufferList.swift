import NIO
import Foundation

public typealias BufferList = NIO.ByteBuffer

public extension ByteBuffer {

    public static func create() -> ByteBuffer {
        return ByteBufferAllocator().buffer(capacity: 4096)
    }

    public var count: Int {
        return self.capacity
    }

    public var data: Data {
       let bytes = self.getBytes(at: 0, length: self.readableBytes) ?? []
       return Data(bytes: bytes) 
    }

    public mutating func append(bytes: UnsafePointer<UInt8>, length: Int) {
        let array = Array(UnsafeBufferPointer(start: bytes, count: length))
        self.write(bytes: array)
    }

    public mutating func append(data: Data) {
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            self.append(bytes: bytes, length: data.count)
        }
    }

    public mutating func fill(array: inout [UInt8]) -> Int {
        return fill(buffer: UnsafeMutablePointer(mutating: array), length: array.count)
    }

    public mutating func fill(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Int {
        let fillLength = min(length, self.readableBytes)
        let bytes = self.readBytes(length: fillLength) ?? []
        UnsafeMutableRawPointer(buffer).copyMemory(from: bytes, byteCount: bytes.count)
        return bytes.count 
    }

    public mutating func fill(data: inout Data) -> Int {
        let bytes = self.readBytes(length: self.readableBytes) ?? []
        data.append(contentsOf: bytes)
        return bytes.count
    }

    public mutating func fill(data: NSMutableData) -> Int {
        let length = self.readableBytes
        let result = self.readWithUnsafeReadableBytes() { body in 
            data.append(body.baseAddress!, length: length) 
            return length
        }
        return result
    }

    public mutating func reset() {
        self.clear()
    }

    public mutating func rewind() {
        self.moveReaderIndex(to: 0)
    }    
}
