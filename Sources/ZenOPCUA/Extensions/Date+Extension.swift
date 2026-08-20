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
    
    /// Pure epoch arithmetic: seconds between 1601-01-01T00:00:00Z (OPC UA
    /// DateTime origin) and 1970-01-01T00:00:00Z (POSIX epoch).
    /// No Calendar/TimeZone involved, so the conversion is DST- and locale-independent.
    private static let secondsBetween1601And1970: TimeInterval = 11_644_473_600

    var ticks: Int64 {
        Int64(((timeIntervalSince1970 + Self.secondsBetween1601And1970) * 10_000_000).rounded())
    }

    internal var bytes: [UInt8] {
        return ticks.bytes
    }
}
