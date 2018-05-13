/*
 * Copyright IBM Corporation 2016, 2017, 2018
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
