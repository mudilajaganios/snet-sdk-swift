//
//  PaymentChannelProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt

protocol PaymentChannelProtocol {
    func getPaymentMetadata() -> [[String: Any]]
    func _getPrice() -> BigUInt
}
