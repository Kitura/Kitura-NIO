/*
* Copyright IBM Corporation 2020
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
import NIOFoundationCompat
import Foundation

class FastCGIRecordDecoderHandler<Decoder: FastCGIDecoder>: ChannelInboundHandler {

    typealias InboundIn = ByteBuffer
    typealias InboundOut = FastCGIRecord

    let keepAlive: Bool
    var data = Data()
    var readCompleteCalls = 0

    public init(keepAlive: Bool = false) {
        self.keepAlive = keepAlive
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.readCompleteCalls = 0
        let request = self.unwrapInboundIn(data)
        let requestData = request.getData(at: 0, length: request.readableBytes) ?? Data()
        self.data.append(requestData)
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        self.readCompleteCalls += 1
        guard self.readCompleteCalls == 2 || self.keepAlive else { return }
        try! Decoder.decode(from: Decoder.unwrap(data)).forEach {
            context.fireChannelRead(self.wrapInboundOut($0))
        }
    }
}
