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

/// The struct that manages the process of upgrading connections from HTTP 1.1 to other protocols.
///
///  - Note: There a single instance of this struct in a server.
public struct ConnectionUpgrader {
    static var instance = ConnectionUpgrader()

    /// Determine if any upgraders have been registered
    static var upgradersExist: Bool {
        return ConnectionUpgrader.instance.registry.count != 0
    }

    private var registry = [String: ProtocolHandlerFactory]()

    /// Register a `ProtocolHandlerFactory` class instances used to create appropriate `NIO.ChannelHandler`s
    /// for upgraded conections
    ///
    /// - Parameter factory: The `ConnectionUpgradeFactory` class instance being registered.
    public static func register(handlerFactory: ProtocolHandlerFactory) {
        ConnectionUpgrader.instance.registry[handlerFactory.name.lowercased()] = handlerFactory
    }

    /// Get the ProtocolHandlerFactory implementation for a given protocol, if it has been registered.
    static func getProtocolHandlerFactory(for `protocol`: String) -> ProtocolHandlerFactory? {
        return ConnectionUpgrader.instance.registry[`protocol`.lowercased()]
    }

    /// Clear the `ConnectionUpgradeFactory` registry.
    static func clear() {
        ConnectionUpgrader.instance.registry.removeAll()
    }
}

/// A protocol that should be implemented by connection upgraders of other protocols like WebSocket.
/// This protocol provides a common interface to the `HTTPServer` to upgrade an incoming HTTP connection
/// to the desired protocol.

public protocol ProtocolHandlerFactory {
    /// Name of the protocol
    var name: String { get }

    /// Supply an NIO channel handler for the protocol. Every upgrade request must get its own handler.
    func handler(for request: ServerRequest) -> ChannelHandler

    /// Checks if a service is available/registered at the given URI
    func isServiceRegistered(at path: String) -> Bool

    // Specially included for the WebSocket protocol. This returns an array of handlers of all enabled extensions.
    func extensionHandlers(header: String) -> [ChannelHandler]

    // Specially included for the WebSocket protocol. This runs the negotiation handshake logic for enabled extensions.
    func negotiate(header: String) -> String
}
