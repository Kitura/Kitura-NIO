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

import KituraNet
import Foundation
import Dispatch

//let fastCGIConnector = FastCGIConnector(url: "http://127.0.0.1:9000", documentRoot: "/usr/local/var/scripts")

class HelloWorldWebServer: ServerDelegate {
    func handle(request: ServerRequest, response: ServerResponse) {
        guard let httpRequest = request as? HTTPServerRequest,
            httpRequest.urlURL.lastPathComponent.contains(".php") else { return }

        let fastCGIConnector = FastCGIConnector(url: "http://127.0.0.1:9000",
                                                documentRoot: "/usr/local/var/scripts")

        try! fastCGIConnector.send(request: httpRequest, keepAlive: false) { responseParts in
            response.statusCode = HTTPStatusCode(rawValue: responseParts.status)
            if let data = responseParts.body {
                try! response.write(from: data)
            }
            try! response.end()
        }
    }
    
    
}

let fastCGIServer = HTTP.createServer()
fastCGIServer.delegate = HelloWorldWebServer()

do {
    try fastCGIServer.listen(on: 8000)
} catch {
    print("Failed to start up fastCGI server")
}

dispatchMain()
