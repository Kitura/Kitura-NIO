#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

import Foundation

// MARK: SPIUtils

/// A set of utility functions.
public class SPIUtils {
    
    /// Abbreviations for month names
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    /// Abbreviations for days of the week
    private static let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    /// Format the given time for use in HTTP, default value is current time.
    ///
    /// - Parameter timestamp: the time ( default value is current timestamp )
    ///
    /// - Returns: string representation of timestamp
    public static func httpDate(from timestamp: time_t = time(nil)) -> String {
        
        var theTime = timestamp
        var timeStruct: tm = tm()
        gmtime_r(&theTime, &timeStruct)
        
        let wday = Int(timeStruct.tm_wday)
        let mday = Int(timeStruct.tm_mday)
        let mon = Int(timeStruct.tm_mon)
        let year = Int(timeStruct.tm_year) + 1900
        let hour = Int(timeStruct.tm_hour)
        let min = Int(timeStruct.tm_min)
        let sec = Int(timeStruct.tm_sec)
        var s = days[wday]
        s.reserveCapacity(30)
        s.append(", ")
        s.append(twoDigit[mday])
        s.append(" ")
        s.append(months[mon])
        s.append(" ")
        s.append(twoDigit[year/100])
        s.append(twoDigit[year%100])
        s.append(" ")
        s.append(twoDigit[hour])
        s.append(":")
        s.append(twoDigit[min])
        s.append(":")
        s.append(twoDigit[sec])
        s.append(" GMT")
        return s
        
    }
    
    /// Format the given date for use in HTTP
    ///
    /// - Parameter date: the date
    ///
    /// - Returns: string representation of Date
    public static func httpDate(_ date: Date) -> String {
        return httpDate(from: time_t(date.timeIntervalSince1970))
    }

    /// Fast Int to String conversion
    private static let twoDigit = ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09",
                                   "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
                                   "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
                                   "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
                                   "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
                                   "50", "51", "52", "53", "54", "55", "56", "57", "58", "59",
                                   "60", "61", "62", "63", "64", "65", "66", "67", "68", "69",
                                   "70", "71", "72", "73", "74", "75", "76", "77", "78", "79",
                                   "80", "81", "82", "83", "84", "85", "86", "87", "88", "89",
                                   "90", "91", "92", "93", "94", "95", "96", "97", "98", "99"]
}


extension Date {
    /// Format the date for use in HTTP
    ///
    /// - Returns: string representation of Date
    var httpDate: String {
        return SPIUtils.httpDate(self)
    }
}

