//
//  RequestHeader.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

struct RequestHeader: OPCUAEncodable {
    var authenticationToken: NodeId = NodeId()
    var timestamp: Date = Date()
    var requestHandle: UInt32 = 0
    var returnDiagnostics: UInt32 = 0 //0x00000000
    var auditEntryId: String? = nil //ff ff ff ff
    var timeoutHint: UInt32 = 0
    var additionalHeader: AdditionalHeader = AdditionalHeader()

    init(requestHandle: UInt32) {
        self.requestHandle = requestHandle
    }
    
    var bytes: [UInt8] {
        return authenticationToken.bytes +
            timestamp.bytes +
            requestHandle.bytes +
            returnDiagnostics.bytes +
            auditEntryId.bytes +
            timeoutHint.bytes +
            additionalHeader.bytes
    }
}
