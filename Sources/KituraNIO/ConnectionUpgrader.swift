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
    var name: String { get }

    func handler(for request: HTTPRequestHead) -> ChannelHandler
}
