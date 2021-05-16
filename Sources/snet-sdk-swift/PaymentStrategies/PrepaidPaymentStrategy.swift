//
//  PrepaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt

class PrepaidPaymentStrategy: BasePaidPaymentStrategy {
    
    fileprivate let _concurrencyManager: ConcurrencyManager
    
    init(serviceClient: ServiceClient, concurrencyManager: ConcurrencyManager, blockOffset: Int = 240, callAllowance: Int = 1) {
        self._concurrencyManager = concurrencyManager
        super.init(serviceClient: serviceClient, blockOffset: BigUInt(blockOffset), callAllowance: BigUInt(callAllowance))
    }
    
    override func getPaymentMetadata() -> [[String : Any]] {
        let concurrentCallsPrice = self._getPrice()
        guard let channel = self._selectChannel(),
              let nonce = channel.state["nonce"] as? Int else { return [] }
        
        let token = self._concurrencyManager.getToken(channel: channel, serviceCallPrice: concurrentCallsPrice)
        let tokenBytes = token.bytes
        
        let metadata = [["snet-payment-type": "prepaid-call"],
                        ["snet-payment-channel-id": channel.channelId],
                        ["snet-payment-channel-nonce": "\(nonce)" ],
                        ["snet-prepaid-auth-token-bin": tokenBytes ]]
        
        return metadata
    }
    
    override func _getPrice() -> BigUInt {
        self._serviceClient._pricePerServiceCall * BigUInt(self._concurrencyManager.concurrentCalls)
    }
}
