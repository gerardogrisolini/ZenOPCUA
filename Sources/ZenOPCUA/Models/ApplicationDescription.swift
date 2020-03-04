//
//  ApplicationDescription.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

enum ApplicationType: UInt32 {
    case server = 0
    case client = 1
    case clientAndServer = 2
    case discoveryServer = 3
}

struct ApplicationDescription {
    var applicationUri: String = ""
    var productUri: String = ""
    var applicationName: LocalizedText = LocalizedText(encodingMask: 0x00, locale: "en-US", text: "")
    var applicationType: ApplicationType = .client
    var gatewayServerUri: String? = nil
    var discoveryProfileUri: String? = nil
    var discoveryUrls: [String] = []
}

public struct LocalizedText {
    public var encodingMask: UInt8 = 0x00
    public var locale: String = ""
    public var text: String = ""
}
