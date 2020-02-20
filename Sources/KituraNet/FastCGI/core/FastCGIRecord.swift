//
//  FastCGIRecordCreate.swift
//  KituraNet
//
//  Created by Rudrani Wankhade on 20/01/20.
//

import Foundation

public struct FastCGIRecord {
    
   public enum ContentType {
        case role (UInt16)
        case data (Data)
        case params ([[String: String]])
        case status (UInt32, UInt8)
    }
    public var version: UInt8 
    public var type: FastCGIRecord.RecordType
    public var requestId: UInt16
    public var contentData: FastCGIRecord.ContentType
    
    
    public enum RecordType: UInt8 {
        case beginRequest = 1 // FCGI_BEGIN_REQUEST
        case endRequest = 3   // FCGI_END_REQUEST
        case params = 4       // FCGI_PARAMS
        case stdin = 5        // FCGI_STDIN
        case stdout = 6       // FCGI_STDOUT
        case data = 8         // FCGI_DATA
    }
 
//    func encode(fastCGIRecordCreate: FastCGIRecordCreate) throws -> Data {
//        try fastCGIRecordCreate.recordTest()
//        let fastCGIRecord = try fastCGIRecordCreate.create()
//        return fastCGIRecord
//    }
//
//    public static func decode (from data: Data?) -> [FastCGIRecord] {
//        var fastCGIRecords: [FastCGIRecord] = []
//        var data = data
//        while data != nil {
//            let data1 = data!
//            let parser = FastCGIRecordParser(data1)
//            data = try! parser.parse()
//            let record = parser.toFastCGIRecord()
//            fastCGIRecords.append(record)
//        }
//        return fastCGIRecords
//    }
}
