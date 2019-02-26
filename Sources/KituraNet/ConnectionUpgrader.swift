/*
 * Copyright IBM Corporation 2016, 2018
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
import NIOHTTP1
import Foundation

public struct ConnectionUpgrader {
    static var instance = ConnectionUpgrader()

    /// Determine if any upgraders have been registered
    static var upgradersExist: Bool {
        return ConnectionUpgrader.instance.registry.count != 0
    }

    private var registry = [String: ProtocolHandlerFactory]()

    public static func register(handlerFactory: ProtocolHandlerFactory) {
        ConnectionUpgrader.instance.registry[handlerFactory.name.lowercased()] = handlerFactory
    }

    static func getProtocolHandlerFactory(for `protocol`: String) -> ProtocolHandlerFactory? {
        return ConnectionUpgrader.instance.registry[`protocol`.lowercased()]
    }

    static func clear() {
        ConnectionUpgrader.instance.registry.removeAll()
    }
}

public protocol ProtocolHandlerFactory {
    // Name of the protocol
    var name: String { get }

    // Supplies an NIO channel handler for the protocol. Every upgrade will return a single handler.
    func handler(for request: ServerRequest) -> ChannelHandler

    // Checks if a service is available/registered at the given URI
    func isServiceRegistered(at path: String) -> Bool

    // Specially included for the WebSocket protocol. This returns an array of handlers of all enabled extensions.
    func extensionHandlers(header: String) -> [ChannelHandler]

    // Specially included for the WebSocket protocol. This runs the negotiation handshake logic for enabled extensions.
    func negotiate(header: String) -> String
}
