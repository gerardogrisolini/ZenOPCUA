//
//  RequestHeader.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

import Foundation

struct RequestHeader: OPCUAEncodable {
    let authenticationTokenValue: NodeValue
    let timestamp: Date = Date()
    let requestHandle: UInt32
    let returnDiagnostics: UInt32 = 0 //0x00000000
    let auditEntryId: String? = nil //ff ff ff ff
    let timeoutHint: UInt32 = 600000
    let additionalHeader: AdditionalHeader = AdditionalHeader()

    init(requestHandle: UInt32, authenticationTokenValue: NodeValue = .base(identifier: 0)) {
        self.requestHandle = requestHandle
        self.authenticationTokenValue = authenticationTokenValue
    }

    internal var bytes: [UInt8] {
        return authenticationTokenValue.bytes +
            timestamp.bytes +
            requestHandle.bytes +
            returnDiagnostics.bytes +
            auditEntryId.bytes +
            timeoutHint.bytes +
            additionalHeader.bytes
    }
}
