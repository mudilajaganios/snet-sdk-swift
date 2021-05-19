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
    func getPaymentMetadata() -> Promise<[[String: Any]]>
    func _getPrice() -> BigUInt
}

extension PaymentChannelProtocol {
    func _getPrice() -> BigUInt {
        return 0
    }
    
    func getPaymentMetadata() -> Promise<[[String: Any]]> {
        return Promise { metadata in
            metadata.fulfill([])
        }
    }
}
