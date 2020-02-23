//
//  GetEndpointsResponse.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

class GetEndpointsResponse: MessageBase, OPCUADecodable {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var endpoints: [EndpointDescription]

    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .getEndpointsResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        endpoints = []
        super.init(bytes: bytes[0...15].map { $0 })

        let count = UInt32(littleEndianBytes: bytes[44...47])
        guard count < UInt32.max else { return }
        
        var index = 48
        for _ in 0..<count {
            let item = EndpointDescription()
            var len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            item.endpointUrl = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
            
            index += len
            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            item.server.applicationUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
            
            index += len
            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            item.server.productUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!

            
            index += len
            item.server.applicationName.encodingMask = bytes[index]
            index += 1

            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if item.server.applicationName.encodingMask == 0x03 && len < UInt32.max {
                item.server.applicationName.locale = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
            }
            if len < UInt32.max {
                item.server.applicationName.text = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }
            
            item.server.applicationType = UInt32(littleEndianBytes: bytes[index..<(index+4)])
            index += 4

            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                item.server.gatewayServerUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }
            
            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                item.server.discoveryProfileUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }

            var innerCount = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if innerCount < UInt32.max {
                for _ in 0..<innerCount {
                    len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                    index += 4
                    if len < UInt32.max {
                        let url = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                        item.server.discoveryUrls.append(url)
                        index += len
                    }
                }
            }
            
            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                item.serverCertificate = bytes[index..<(index+len)].map { $0 }
                index += len
            }
            
            item.messageSecurityMode = UInt32(littleEndianBytes: bytes[index..<(index+4)])
            index += 4

            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                item.securityPolicyUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }

            innerCount = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if innerCount < UInt32.max {
                for _ in 0..<innerCount {
                    var identity = UserTokenPolicy()
                    
                    len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                    index += 4
                    if len < UInt32.max {
                        identity.policyId = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                        index += len
                    }

                    identity.userTokenType = UInt32(littleEndianBytes: bytes[index..<(index+4)])
                    index += 4

                    len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                    index += 4
                    if len < UInt32.max {
                        identity.issuedTokenType = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                        index += len
                    }

                    len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                    index += 4
                    if len < UInt32.max {
                        identity.issuerEndpointUrl = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                        index += len
                    }

                    len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                    index += 4
                    if len < UInt32.max {
                        identity.securityPolicyUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                        index += len
                    }

                    item.userIdentityTokens.append(identity)
                }
            }

            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                item.transportProfileUri = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }

            item.securityLevel = bytes[index]
            index += 1
            
            endpoints.append(item)
        }
    }
}
