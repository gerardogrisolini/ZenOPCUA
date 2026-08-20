//
//  Int64+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import Foundation

extension Int64: OPCUAEncodable {
    /// Seconds between 1601-01-01T00:00:00Z (OPC UA DateTime origin) and
    /// 1970-01-01T00:00:00Z (POSIX epoch). Shared with `Date.ticks`.
    private static let secondsBetween1601And1970: TimeInterval = 11_644_473_600

    /// Decodes OPC UA ticks into a `Date`. Pure epoch arithmetic: no
    /// Calendar/TimeZone, so decoding is locale- and DST-independent.
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(self) / 10_000_000 - Self.secondsBetween1601And1970)
    }

    /// Legacy alias of `date`: previously it applied a different (incorrect)
    /// offset, both names now share the same correct implementation.
    var dateUtc: Date {
        date
    }
}
