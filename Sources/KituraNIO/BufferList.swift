import NIO
import Foundation

public class BufferList {

    var byteBuffer: ByteBuffer

    public init() {
         byteBuffer = ByteBufferAllocator().buffer(capacity: 4096)
    }

    init(with byteBuffer: ByteBuffer) {
        self.byteBuffer = byteBuffer
    }
    
    public var count: Int {
        return byteBuffer.capacity
    }

    public var data: Data {
       let bytes = byteBuffer.getBytes(at: 0, length: byteBuffer.readableBytes) ?? []
       return Data(bytes: bytes) 
    }

    public func append(bytes: UnsafePointer<UInt8>, length: Int) {
        let array = Array(UnsafeBufferPointer(start: bytes, count: length))
        byteBuffer.write(bytes: array)
    }

    public func append(data: Data) {
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            self.append(bytes: bytes, length: data.count)
        }
    }

    public func fill(array: inout [UInt8]) -> Int {
        return fill(buffer: UnsafeMutablePointer(mutating: array), length: array.count)
    }

    public func fill(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Int {
        let fillLength = min(length, byteBuffer.readableBytes)
        let bytes = byteBuffer.readBytes(length: fillLength) ?? []
        UnsafeMutableRawPointer(buffer).copyMemory(from: bytes, byteCount: bytes.count)
        return bytes.count 
    }

    public func fill(data: inout Data) -> Int {
        let bytes = byteBuffer.readBytes(length: byteBuffer.readableBytes) ?? []
        data.append(contentsOf: bytes)
        return bytes.count
    }

    public func fill(data: NSMutableData) -> Int {
        let length = byteBuffer.readableBytes
        let result = byteBuffer.readWithUnsafeReadableBytes() { body in 
            data.append(body.baseAddress!, length: length) 
            return length
        }
        return result
    }

    public func reset() {
        byteBuffer.clear()
    }

    public func rewind() {
        byteBuffer.moveReaderIndex(to: 0)
    }    
}
