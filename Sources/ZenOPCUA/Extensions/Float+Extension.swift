//
//  File.swift
//  
//
//  Created by Gerardo Grisolini on 12/09/21.
//

import Foundation

extension Float: OPCUAEncodable, OPCUADecodable {
	
	init(bytes: [UInt8]) {
		precondition(bytes.count == MemoryLayout<Float>.size)
		self = bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
	}

	internal var bytes: [UInt8] {
		var _self = self
		let bytePtr = withUnsafePointer(to: &_self) {
			$0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Self>.size) {
				UnsafeBufferPointer(start: $0, count: MemoryLayout<Self>.size)
			}
		}
		return [UInt8](bytePtr)
	}
}
