//
//  PaymentStrategyProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 16/05/2021.
//

import Foundation
import PromiseKit
import BigInt

public protocol PaymentStrategyProtocol {
    var _concurrentCalls: Int { get set }
    var selectedChannelId: Int { get set }
    init(concurrentCalls: Int)
    func getPaymentMetadata(serviceClient: ServiceClientProtocol) -> Promise<[[String : Any]]>
}
