//
//  ErrorResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

enum ErrorResponse: UInt32 {
    case badEncodingLimitsExceeded = 2148007936
    case badServiceUnsupported = 2148204544
    case malformedPacket = 2159017984
    case chunkSizeExceededMaximum = 2155872256 //maximum (8196)
    case badSecurityPolicyRejected = 2153054208
}
