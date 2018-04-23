import NIOOpenSSL
import SSLService

internal class SSLConfiguration {
   
    private var certificateFilePath: String? = nil
    
    private var keyFilePath: String? = nil
    
    // TODO: Consider other TLSConfiguration options (cipherSuites, trustRoots, applicationProtocols, etc..)
    
    init(sslConfig: SSLService.Configuration) {
        self.certificateFilePath = sslConfig.certificateFilePath
        self.keyFilePath = sslConfig.keyFilePath
    }
    
    func tlsServerConfig() -> TLSConfiguration? {
        #if os(Linux)
            // TODO: Consider other configuration options
            if let certificateFilePath = certificateFilePath, let keyFilePath = keyFilePath {
                return TLSConfiguration.forServer(certificateChain: [.file(certificateFilePath)], privateKey: .file(keyFilePath))
            } else {
                return nil
            }
        #else
            // TODO: Add support for other platforms
            fatalError("Not supported")
        #endif
    }
}
