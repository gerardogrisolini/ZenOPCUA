//
//  OPCUAFrame+Extension.swift
//  
//
//  Created by Gerardo Grisolini on 28/09/2020.
//

extension OPCUAFrame {

    func split(bufferSize: Int = 8196) -> [OPCUAFrame] {
        var frames = [OPCUAFrame]()
        if head.messageSize > bufferSize {
            var index = 0
            while index < head.messageSize {
                //print("\(index) < \(self.head.messageSize)")
                let part: OPCUAFrame
                if (index + bufferSize - 8) >= head.messageSize {
                    let body = self.body[index...].map { $0 }
                    part = OPCUAFrame(head: head, body: body)
                } else {
                    let head = OPCUAFrameHead(messageType: .message, chunkType: .part)
                    let body = self.body[index..<(index + bufferSize - 8)].map { $0 }
                    part = OPCUAFrame(head: head, body: body)
                }
                index += bufferSize - 8
                frames.append(part)
            }
        } else {
            frames.append(self)
        }
        return frames
    }
}
