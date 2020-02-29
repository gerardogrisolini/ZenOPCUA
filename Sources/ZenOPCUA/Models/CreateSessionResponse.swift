//
//  CreateSessionResponse.swift
//  
//
//  Created by Gerardo Grisolini on 18/02/2020.
//

import Foundation

class CreateSessionResponse: MessageBase {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    let sessionId: Node
    let authenticationToken: Node
    let revisedSessionTimeout: Double
    var serverNonce: [UInt8] = []
    var serverCertificate: [UInt8] = []
    var serverEndpoints: [EndpointDescription] = []
    var serverSoftwareCertificates: String? = nil
    var serverSignature: SignatureData = SignatureData()
    var maxRequestMessageSize: UInt32 = 0
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .createSessionResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        var index = 44
        
        sessionId = Nodes.node(index: &index, bytes: bytes)
        authenticationToken = Nodes.node(index: &index, bytes: bytes)

        revisedSessionTimeout = Double(bytes: bytes[index..<(index+8)].map { $0 })
        index += 8
        
        var len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
        index += 4
        if len < UInt32.max {
            serverNonce = bytes[index..<(index+len)].map { $0 }
            index += len
        }
            
        len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
        index += 4
        if len < UInt32.max {
            serverCertificate = bytes[index..<(index+len)].map { $0 }
            index += len
        }

        super.init(bytes: bytes[0...15].map { $0 })

        let count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        guard count < UInt32.max else { return }
        index += 4
        
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
            
            serverEndpoints.append(item)
        }
    }
}

struct SignatureData: OPCUAEncodable {
    let algorithm: String? = nil
    let signature: String? = nil

    var bytes: [UInt8] {
        return algorithm.bytes + signature.bytes
    }
}
