//
//  GetEndpointsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class GetEndpointsResponse: MessageBase, OPCUADecodable, @unchecked Sendable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var endpoints: [EndpointDescription]

    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .getEndpointsResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        endpoints = []
        super.init(bytes: bytes[0...15].map { $0 })

        let count = UInt32(bytes: bytes[44...47])
        guard count < UInt32.max else { return }
        
        var index = 48
        
        for _ in 0..<count {
            let item = EndpointDescription()
            var len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            
            if let url = String(bytes: bytes[index..<(index+len.int)], encoding: .utf8) {
                item.endpointUrl = url
            }
            index += len.int
            
            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            item.server.applicationUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
            
            index += len.int
            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            item.server.productUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)

            index += len.int
            item.server.applicationName.encodingMask = bytes[index]
            index += 1

            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if item.server.applicationName.encodingMask == 0x03 && len < UInt32.max {
                item.server.applicationName.locale = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                index += len.int
                len = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
            }
            if len < UInt32.max {
                item.server.applicationName.text = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                index += len.int
            }
            
            item.server.applicationType = ApplicationType(rawValue: UInt32(bytes: bytes[index..<(index+4)]))!
            index += 4

            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if len < UInt32.max {
                item.server.gatewayServerUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                index += len.int
            }
            
            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if len < UInt32.max {
                item.server.discoveryProfileUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                index += len.int
            }

            var innerCount = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if innerCount < UInt32.max {
                for _ in 0..<innerCount {
                    len = UInt32(bytes: bytes[index..<(index+4)])
                    index += 4
                    if len < UInt32.max {
                        let url = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                        item.server.discoveryUrls.append(url)
                        index += len.int
                    }
                }
            }
            
            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if len < UInt32.max {
                item.serverCertificate = bytes[index..<(index+len.int)].map { $0 }
                index += len.int
            }
            
            item.messageSecurityMode = MessageSecurityMode(rawValue: UInt32(bytes: bytes[index..<(index+4)]))!
            index += 4

            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if len < UInt32.max {
                item.securityPolicyUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                index += len.int
            }

            innerCount = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if innerCount < UInt32.max {
                for _ in 0..<innerCount {
                    var identity = UserTokenPolicy()
                    
                    len = UInt32(bytes: bytes[index..<(index+4)])
                    index += 4
                    if len < UInt32.max {
                        identity.policyId = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                        index += len.int
                    }

                    identity.tokenType = UserTokenType(rawValue: UInt32(bytes: bytes[index..<(index+4)]))!
                    index += 4

                    len = UInt32(bytes: bytes[index..<(index+4)])
                    index += 4
                    if len < UInt32.max {
                        identity.issuedTokenType = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                        index += len.int
                    }

                    len = UInt32(bytes: bytes[index..<(index+4)])
                    index += 4
                    if len < UInt32.max {
                        identity.issuerEndpointUrl = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                        index += len.int
                    }

                    len = UInt32(bytes: bytes[index..<(index+4)])
                    index += 4
                    if len < UInt32.max {
                        identity.securityPolicyUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                        index += len.int
                    }

                    item.userIdentityTokens.append(identity)
                }
            }

            len = UInt32(bytes: bytes[index..<(index+4)])
            index += 4
            if len < UInt32.max {
                item.transportProfileUri = String(decoding: bytes[index..<(index+len.int)], as: UTF8.self)
                index += len.int
            }

            item.securityLevel = bytes[index]
            index += 1
            
            endpoints.append(item)
        }
    }
}
