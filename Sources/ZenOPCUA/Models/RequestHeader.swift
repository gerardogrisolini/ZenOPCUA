//
//  RequestHeader.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

struct RequestHeader: OPCUAEncodable {
    let authenticationToken: OPCUAEncodable
    let timestamp: Date = Date()
    let requestHandle: UInt32
    let returnDiagnostics: UInt32 = 0 //0x00000000
    let auditEntryId: String? = nil //ff ff ff ff
    let timeoutHint: UInt32 = 0
    let additionalHeader: AdditionalHeader = AdditionalHeader()

    init(requestHandle: UInt32, authenticationToken: OPCUAEncodable = NodeId()) {
        self.requestHandle = requestHandle
        self.authenticationToken = authenticationToken
    }
    
    internal var bytes: [UInt8] {
        return authenticationToken.bytes +
            timestamp.bytes +
            requestHandle.bytes +
            returnDiagnostics.bytes +
            auditEntryId.bytes +
            timeoutHint.bytes +
            additionalHeader.bytes
    }
}
