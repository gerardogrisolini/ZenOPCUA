//
//  ApplicationDescription.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

struct ApplicationDescription {
    var applicationUri: String = ""
    var productUri: String = ""
    var applicationName: LocalizedText = LocalizedText(encodingMask: 0x00, locale: "en-US", text: "")
    var applicationType: UInt32 = 1
    var gatewayServerUri: String? = nil
    var discoveryProfileUri: String? = nil
    var discoveryUrls: [String] = []
}

public struct LocalizedText {
    public var encodingMask: UInt8 = 0x00
    public var locale: String = ""
    public var text: String = ""
}
