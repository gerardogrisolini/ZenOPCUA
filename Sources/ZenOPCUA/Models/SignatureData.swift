//
//  SignatureData.swift
//  
//
//  Created by Gerardo Grisolini on 15/03/2020.
//

struct SignatureData: OPCUAEncodable {
    var algorithm: String? = nil
    var signature: [UInt8] = []

    internal var bytes: [UInt8] {
        return algorithm.bytes + signature
    }
}
