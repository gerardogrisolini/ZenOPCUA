//
//  Nodes+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 08/03/2020.
//

extension String.StringInterpolation {
    mutating func appendInterpolation(_ nodeValue: NodeValue) {
        switch nodeValue {
        case .base(let identifier):
            appendInterpolation("NodeValue.base { identifier = \(identifier) }")
        case .compact(let encoding, let identifier):
            appendInterpolation("NodeValue.compact { encoding = \(encoding), identifier = \(identifier) }")
        case .numeric(let nameSpace, let identifier):
            appendInterpolation("NodeValue.numeric { nameSpace = \(nameSpace), identifier = \(identifier) }")
        case .long(let nameSpace, let identifier):
            appendInterpolation("NodeValue.long { nameSpace = \(nameSpace), identifier = \(identifier) }")
        case .string(let nameSpace, let identifier):
            appendInterpolation("NodeValue.string { nameSpace = \(nameSpace), identifier = \(identifier) }")
        case .guid(let nameSpace, let identifier):
            appendInterpolation("NodeValue.guid { nameSpace = \(nameSpace), identifier = \(identifier) }")
        case .byteString(let nameSpace, let identifier):
            appendInterpolation("NodeValue.byteString { nameSpace = \(nameSpace), identifier = \(identifier) }")
        case .baseExt(let identifier, let serverIndex):
            appendInterpolation("NodeValue.baseExt { identifier = \(identifier), serverIndex = \(serverIndex) }")
        case .numericExt(let nameSpace, let identifier, let serverIndex):
            appendInterpolation("NodeValue.numericExt { nameSpace = \(nameSpace), identifier = \(identifier), serverIndex = \(serverIndex) }")
        case .stringExt(let nameSpace, let identifier, let serverIndex):
            appendInterpolation("NodeValue.stringExt { nameSpace = \(nameSpace), identifier = \(identifier), serverIndex = \(serverIndex) }")
        }
    }
}
