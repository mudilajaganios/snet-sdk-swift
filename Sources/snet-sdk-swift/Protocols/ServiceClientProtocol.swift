//
//  ServiceClientProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 16/05/2021.
//

import Foundation
import PromiseKit
import GRPC
import BigInt

public protocol ServiceClientProtocol {
    var serviceChannel: GRPCChannel { get }
    func getServiceClientOptions() -> Promise<CallOptions?>
}

protocol ServiceClientStateProtocol {
    var group: [String: Any] { get }
    func getChannelState(channelId: BigUInt) -> Promise<Escrow_ChannelStateReply>
}
