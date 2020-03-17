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

struct ApplicationDescription: OPCUAEncodable {
    var applicationUri: String = ""
    var productUri: String = ""
    var applicationName: LocalizedText
    var applicationType: ApplicationType = .client
    var gatewayServerUri: String? = nil
    var discoveryProfileUri: String? = nil
    var discoveryUrls: [String] = []

    init(applicationName: String = "") {
        self.applicationName = LocalizedText(locale: "en-US", text: applicationName)
    }
    
    internal var bytes: [UInt8] {
        let uris = UInt32(discoveryUrls.count).bytes + discoveryUrls.map { $0.bytes }.reduce([], +)
        return applicationUri.bytes +
            productUri.bytes +
            applicationName.bytes +
            applicationType.rawValue.bytes +
            gatewayServerUri.bytes +
            discoveryProfileUri.bytes +
            uris
    }
}

public struct LocalizedText: OPCUAEncodable {
    public var encodingMask: UInt8 = 0x03
    public var locale: String = ""
    public var text: String = ""

    internal var bytes: [UInt8] {
        if encodingMask == 0x03 {
            return [encodingMask] + locale.bytes + text.bytes
        }
        return [encodingMask] + text.bytes
    }
}
