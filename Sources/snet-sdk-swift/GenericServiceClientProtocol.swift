//
//  GenericServiceClientProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 17/05/2021.
//

import Foundation
import GRPC

public protocol GenericServiceClientProtocol {
    init(channel: GRPCChannel    )
}
