//
//  Nodes.swift
//  
//
//  Created by Gerardo Grisolini on 17/02/2020.
//

enum Nodes: UInt16 {
    case userIdentityToken = 321
    case openSecureChannelRequest = 446
    case openSecureChannelResponse = 449
    case getEndpointsRequest = 428
    case getEndpointsResponse = 431
    case createSessionRequest = 461
    case createSessionResponse = 464
    case activateSessionRequest = 467
    case activateSessionResponse = 470
    case closeSessionRequest = 473
    case closeSessionResponse = 476
    case closeSecureChannelRequest = 452
}
