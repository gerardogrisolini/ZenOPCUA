//
//  UInt32+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension UInt32: Promisable { }

extension UInt32 {
    var int: Int { 
        guard self <= Int.max else {
        return 0
        }
        return Int(self) 
    }
}
