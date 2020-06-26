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

import Foundation

public struct FastCGIRecord {

    public enum Content {
        case beginRecordContent(UInt16, UInt8)
        case status(UInt32, UInt8)
        case params([[String: String]])
        case data(Data)
    }

    public enum RecordType: UInt8 {
        case beginRequest = 1 // FCGI_BEGIN_REQUEST
        case endRequest = 3   // FCGI_END_REQUEST 
        case params = 4       // FCGI_PARAMS
        case stdin = 5        // FCGI_STDIN
        case stdout = 6       // FCGI_STDOUT
        case stderr = 7       // FCGI_STDERR
        case data = 8         // FCGI_DATA
    }

    let version: UInt8
    let type: FastCGIRecord.RecordType 
    let requestId: UInt16
    let content: FastCGIRecord.Content
    var crossRecord = false
}
