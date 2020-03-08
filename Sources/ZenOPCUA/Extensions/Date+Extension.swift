//
//  Date+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

// An instance in time. A DateTime value is encoded as a 64-bit signed integer
// which represents the number of 100 nanosecond intervals since January 1, 1601
// (UTC).

import Foundation

extension Date : OPCUAEncodable {
    
    var ticks: Int64 {
        let calendar = Calendar.current
        let dstComponents = DateComponents(year: 1601,
            month: 1,
            day: 1)
        if #available(OSX 10.12, *) {
            let interval = DateInterval(start: calendar.date(from: dstComponents)!, end: self).duration
            return Int64(TimeInterval(interval * 10000000))
        } else {
            return 0
        }
    }

    internal var bytes: [UInt8] {
        return ticks.bytes
    }
}
