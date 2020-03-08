//
//  String+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

import CryptoSwift

extension String {

    func aesEncrypt() throws -> String {
        
        let key: Array<UInt8> = [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]
        let iv: Array<UInt8> = key

        let aes = try! AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs5) // AES128 .CBC pkcs5
        let encrypted = try aes.encrypt(Array(self.utf8))
        let result = encrypted.toHexString()//.toBase64()!

        print("AES Encryption Result: \(result)")

        return result
    }
}
