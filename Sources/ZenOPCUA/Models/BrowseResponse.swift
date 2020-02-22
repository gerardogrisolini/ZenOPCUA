//
//  BrowseResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

class BrowseResponse: MessageBase {
    let typeId: NodeIdNumeric
    let responseHeader: ResponseHeader
    var results: [BrowseResult] = []
    var diagnosticInfos: [DiagosticInfo] = []
    
    required override init(bytes: [UInt8]) {
        typeId = NodeIdNumeric(identifier: .browseResponse)
        let part = bytes[20...43].map { $0 }
        responseHeader = ResponseHeader(bytes: part)
        super.init(bytes: bytes[0...15].map { $0 })

        var index = 44
        var len = 0
        
        var count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        if count == UInt32.max { count = 0 }
        index += 4
        for _ in 0..<count {
            let statusCode = StatusCodes(rawValue: UInt32(littleEndianBytes: bytes[index..<(index+4)]))!
            var result = BrowseResult(statusCode: statusCode)
            index += 4

            len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            if len < UInt32.max {
                result.continuationPoint = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                index += len
            }
            
            let innerCount = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
            index += 4
            for _ in 0..<innerCount {
                var reference = ReferenceDescription()
                reference.referenceTypeId.encodingMask = bytes[index]
                index += 1
                reference.referenceTypeId.identifierNumeric = bytes[index]
                index += 1
                reference.isForward = Bool(byte: bytes[index])
                index += 1
                
                switch bytes[index] {
                case 0x01:
                    let nodeId = NodeIdNumeric(
                        nameSpace: bytes[index+1],
                        identifier: UInt16(littleEndianBytes: bytes[(index+2)...(index+3)])
                    )
                    reference.nodeId = nodeId
                    index += 4
                case 0x03:
                    len = Int(UInt32(littleEndianBytes: bytes[(index+3)..<(index+7)]))
                    if len < UInt32.max {
                        let nodeId = NodeIdString(
                            nameSpace: UInt16(littleEndianBytes: bytes[(index+1)...(index+2)]),
                            identifier: String(bytes: bytes[(index+7)..<(index+len+7)], encoding: .utf8)!
                        )
                        reference.nodeId = nodeId
                        index += len
                    }
                    index += 3 + 4
                default:
                    reference.nodeId = NodeId(bytes: bytes[index...(index+1)].map { $0 })
                    index += 2
                }
                
                reference.browseName.id = UInt16(littleEndianBytes: bytes[index..<(index+2)])
                index += 2
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
                if len < UInt32.max {
                    reference.browseName.name = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                    index += len
                }
                
                reference.displayName.encodingMask = bytes[index]
                index += 1
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
                if reference.displayName.encodingMask == 0x03 && len < UInt32.max {
                    reference.displayName.locale = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                    index += len
                    len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                    index += 4
                }
                if len < UInt32.max {
                    reference.displayName.text = String(bytes: bytes[index..<(index+len)], encoding: .utf8)!
                    index += len
                }
                
                reference.nodeClass = UInt32(littleEndianBytes: bytes[index..<(index+4)])
                index += 4
                
                if bytes[index] == 0x00 {
                    reference.typeDefinition = NodeId(bytes: bytes[index...(index+1)].map { $0 })
                    index += 2
                } else {
                    let nodeId = NodeIdNumeric(
                        nameSpace: bytes[index+1],
                        identifier: UInt16(littleEndianBytes: bytes[(index+2)...(index+3)])
                    )
                    reference.typeDefinition = nodeId
                    index += 4
                }
                
                result.references.append(reference)
            }
            
            results.append(result)
        }

        count = UInt32(littleEndianBytes: bytes[index..<(index+4)])
        index += 4
        if count < UInt32.max {
            for _ in 0..<count {
                len = Int(UInt32(littleEndianBytes: bytes[index..<(index+4)]))
                index += 4
                if let text = String(bytes: bytes[index..<(index+len)], encoding: .utf8) {
                    let info = DiagosticInfo(info: text)
                    diagnosticInfos.append(info)
                }
                index += len
            }
        }
    }
}

struct BrowseResult {
    var statusCode: StatusCodes
    var continuationPoint: String? = nil
    var references: [ReferenceDescription] = []
}

struct ReferenceDescription {
    var referenceTypeId: NodeId = NodeId()
    var isForward: Bool = true
    var nodeId: OPCUAEncodable!
    var browseName: QualifiedName = QualifiedName()
    var displayName: LocalizedText = LocalizedText()
    var nodeClass: UInt32 = 0
    var typeDefinition: OPCUAEncodable!
}

public struct QualifiedName: OPCUAEncodable {
    public var id: UInt16 = 0
    public var name: String? = nil

    var bytes: [UInt8] {
        return id.bytes + name.bytes
    }
}
