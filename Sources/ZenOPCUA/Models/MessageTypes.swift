//
//  MessageTypes.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

public enum MessageTypes: String {
    case hello = "HEL"
    case acknowledge = "ACK"
    case openChannel = "OPN"
    case closeChannel = "CLO"
    case message = "MSG"
    case error = "ERR"
}
