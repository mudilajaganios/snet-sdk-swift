//
//  PaymentChannelProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt
import PromiseKit

protocol PaymentChannelProtocol {
    func getPaymentMetadata(selectedChannel: Int?) -> Promise<[[String: Any]]>
    func _getPrice() -> BigUInt
}
