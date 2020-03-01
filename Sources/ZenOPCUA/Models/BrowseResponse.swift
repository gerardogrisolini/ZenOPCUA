//
//  BrowseResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

import Foundation

class BrowseResponse: MessageBase {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [BrowseResult] = []
    var diagnosticInfos: [DiagnosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(method: .browseResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })

        var index = 44
        var len = 0
        
        var count = UInt32(bytes: bytes[index..<(index+4)])
        if count == UInt32.max { count = 0 }
        index += 4
        for _ in 0..<count {
            let statusCode = StatusCodes(rawValue: UInt32(bytes: bytes[index..<(index+4)]))!
            var result = BrowseResult(statusCode: statusCode)
            index += 4

            len = Int(UInt32(bytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                result.continuationPoint = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }
            
            let innerCount = Int(UInt32(bytes: bytes[index..<(index+4)]))
            index += 4
            if innerCount < UInt32.max {
            for _ in 0..<innerCount {
                var reference = ReferenceDescription()
                reference.referenceTypeId.encodingMask = Nodes(rawValue: bytes[index])!
                index += 1
                reference.referenceTypeId.identifier = bytes[index]
                index += 1
                reference.isForward = Bool(byte: bytes[index])
                index += 1
                
                reference.nodeId = Nodes.node(index: &index, bytes: bytes)
                reference.browseName.id = UInt16(bytes: bytes[index..<(index+2)])
                index += 2
                len = Int(UInt32(bytes: bytes[index..<(index+4)]))
                index += 4
                if len < UInt32.max {
                    reference.browseName.name = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                    index += len
                }
                
                reference.displayName.encodingMask = bytes[index]
                index += 1
                len = Int(UInt32(bytes: bytes[index..<(index+4)]))
                index += 4
                if reference.displayName.encodingMask == 0x03 && len < UInt32.max {
                    reference.displayName.locale = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                    index += len
                    len = Int(UInt32(bytes: bytes[index..<(index+4)]))
                    index += 4
                }
                if len < UInt32.max {
                    reference.displayName.text = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                    index += len
                }
                
                reference.nodeClass = UInt32(bytes: bytes[index..<(index+4)])
                index += 4
                
                reference.typeDefinition = Nodes.node(index: &index, bytes: bytes)
               
                result.references.append(reference)
            }
            }
            
            results.append(result)
        }

        count = UInt32(bytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                len = Int(UInt32(bytes: bytes[index..<(index+4)]))
                index += 4
                if let text = String(bytes: bytes[index..<(index+len)], encoding: .utf8) {
                    let info = DiagnosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
                index += len
            }
        }
    }
}

public struct BrowseResult: Promisable {
    public var statusCode: StatusCodes
    public var continuationPoint: String? = nil
    public var references: [ReferenceDescription] = []
}

public struct ReferenceDescription {
    public var referenceTypeId: NodeId = NodeId()
    public var isForward: Bool = true
    public var nodeId: Node = Node(.numeric)
    public var browseName: QualifiedName = QualifiedName()
    public var displayName: LocalizedText = LocalizedText()
    public var nodeClass: UInt32 = 0
    public var typeDefinition: Node!
}

public struct QualifiedName: OPCUAEncodable {
    public var id: UInt16 = 0
    public var name: String? = nil

    var bytes: [UInt8] {
        return id.bytes + name.bytes
    }
}
