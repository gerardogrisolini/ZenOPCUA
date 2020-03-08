//
//  Bool+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension Bool {
    
    init(byte: UInt8) {
        self = byte == 0x01 ? true : false
    }

    internal var bytes: [UInt8] {
        return [self ? 0x01 : 0x00]
    }
}
