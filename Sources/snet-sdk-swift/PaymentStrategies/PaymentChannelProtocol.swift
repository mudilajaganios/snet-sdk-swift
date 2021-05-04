//
//  PaymentChannelProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation

protocol PaymentChannelProtocol: class {
    func getPaymentMetadata()
    func _getPrice()
}
