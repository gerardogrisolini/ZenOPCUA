//
//  BrowseResponse.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

import Foundation

struct BrowseResponse: Sendable {
    let header: MessageHeader
    let typeId: NodeValue
    let responseHeader: ResponseHeader
    let results: [BrowseResult]
    let diagnosticInfos: [DiagnosticInfo]
    
    init(bytes: [UInt8]) {
        typeId = NodeValue(method: .browseResponse)
        if bytes.count >= 44 {
            let part = bytes[20...43].map { $0 }
            responseHeader = ResponseHeader(bytes: part)
        } else {
            responseHeader = ResponseHeader(bytes: [UInt8](repeating: 0, count: 24))
        }
        header = MessageHeader(bytes: bytes.count >= 16 ? bytes[0...15].map { $0 } : [])

        var index = 44
        var parsedResults: [BrowseResult] = []
        var parsedDiagnosticInfos: [DiagnosticInfo] = []

        func readUInt32Safe() -> UInt32? {
            guard index + 4 <= bytes.count else { return nil }
            let value = UInt32(bytes: bytes[index..<(index + 4)])
            index += 4
            return value
        }

        func readUInt16Safe() -> UInt16? {
            guard index + 2 <= bytes.count else { return nil }
            let value = UInt16(bytes: bytes[index..<(index + 2)])
            index += 2
            return value
        }

        func readByteSafe() -> UInt8? {
            guard index < bytes.count else { return nil }
            let value = bytes[index]
            index += 1
            return value
        }

        func readStringSafe() -> String? {
            guard let len = readUInt32Safe(), len != UInt32.max else { return nil }
            let count = len.int
            guard index + count <= bytes.count else { return nil }
            let text = String(bytes: bytes[index..<(index + count)], encoding: .utf8)
            index += count
            return text
        }

        let parse: () -> Void = {
            var count = readUInt32Safe() ?? 0
            if count == UInt32.max { count = 0 }
            for _ in 0..<count {
                guard let rawStatus = readUInt32Safe() else { break }
                let statusCode = StatusCodes(rawValue: rawStatus) ?? .UA_STATUSCODE_BADDATAENCODINGINVALID
                var result = BrowseResult(statusCode: statusCode)

                result.continuationPoint = readStringSafe()
                
                let innerCount = readUInt32Safe() ?? 0
                if innerCount < UInt32.max {
                    for _ in 0..<innerCount {
                        var reference = ReferenceDescription()
                        let referenceEncoding = readByteSafe().flatMap(Nodes.init(rawValue:)) ?? .numeric
                        let referenceIdentifier = readByteSafe() ?? 0
                        reference.referenceTypeValue = .compact(
                            encoding: referenceEncoding,
                            identifier: referenceIdentifier
                        )
                        reference.isForward = Bool(byte: readByteSafe() ?? 0)
                        
                        reference.nodeValue = NodeValue.parse(index: &index, bytes: bytes)
                        reference.browseName.id = readUInt16Safe() ?? 0
                        reference.browseName.name = readStringSafe()
                        
                        reference.displayName.encodingMask = readByteSafe() ?? 0
                        if reference.displayName.encodingMask == 0x03 {
                            reference.displayName.locale = readStringSafe() ?? ""
                        }
                        reference.displayName.text = readStringSafe() ?? ""
                        
                        reference.nodeClass = readUInt32Safe() ?? 0
                        reference.typeDefinitionValue = NodeValue.parse(index: &index, bytes: bytes)
                       
                        result.references.append(reference)
                    }
                }
                
                parsedResults.append(result)
            }

            count = readUInt32Safe() ?? 0
            if count < UInt32.max {
                for _ in 0..<count {
                    if let text = readStringSafe() {
                        let info = DiagnosticInfo(info: text)
                        parsedDiagnosticInfos.append(info)
                    }
                }
            }
        }
        parse()
        results = parsedResults
        diagnosticInfos = parsedDiagnosticInfos
    }
}

public struct BrowseResult: Promisable, Sendable {
    public var statusCode: StatusCodes
    public var continuationPoint: String? = nil
    public var references: [ReferenceDescription] = []
}

public struct ReferenceDescription: Sendable {
    public var referenceTypeValue: NodeValue = .base(identifier: 0)
    public var isForward: Bool = true
    public var nodeValue: NodeValue = .numeric(nameSpace: 0, identifier: 0)
    public var browseName: QualifiedName = QualifiedName()
    public var displayName: LocalizedText = LocalizedText()
    public var nodeClass: UInt32 = 0
    public var typeDefinitionValue: NodeValue? = nil
}

public struct QualifiedName: OPCUAEncodable, Sendable {
    public var id: UInt16 = 0
    public var name: String? = nil

    public init() {
    }
    
    internal var bytes: [UInt8] {
        return id.bytes + name.bytes
    }
}
