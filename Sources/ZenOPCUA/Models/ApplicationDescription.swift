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

struct LocalizedText {
    var encodingMask: UInt8 = 0x00
    var locale: String = ""
    var text: String = ""
}
