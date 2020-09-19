//
//  Int64+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation

extension Int64: OPCUAEncodable{
    var date: Date {
        let dstComponents = DateComponents(year: 1601,
            month: 1,
            day: 1)
        let start = Calendar.current.date(from: dstComponents)!
        let timezone = Int64(3000 + TimeZone.current.secondsFromGMT())
        return Date(timeInterval: TimeInterval(self / 10000000 + timezone), since: start)
    }

    var dateUtc: Date {
        let dstComponents = DateComponents(year: 1601,
            month: 1,
            day: 1)
        let start = Calendar.current.date(from: dstComponents)!
        return Date(timeInterval: TimeInterval(self / 10000000) + 3000, since: start)
    }
}
