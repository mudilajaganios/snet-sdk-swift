//
//  PrepaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt
import PromiseKit

class PrepaidPaymentStrategy: BasePaidPaymentStrategy {
    
    fileprivate let _concurrencyManager: ConcurrencyManager
    
    init(serviceClient: ServiceClient, concurrencyManager: ConcurrencyManager, blockOffset: Int = 240, callAllowance: Int = 1) {
        self._concurrencyManager = concurrencyManager
        super.init(serviceClient: serviceClient, blockOffset: BigUInt(blockOffset), callAllowance: BigUInt(callAllowance))
    }
    
    func getPaymentMetadata() -> Promise<[[String : Any]]> {
        return firstly {
            self._selectChannel()
        }.then { (channel) -> Promise<[[String : Any]]> in
            return Promise { metadatapromise in
                guard let nonce = channel.state["nonce"] else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get organization metadata"])
                    metadatapromise.reject(genericError)
                    return }
                
                let concurrentCallsPrice = self._getPrice()
                let token = self._concurrencyManager.getToken(channel: channel, serviceCallPrice: concurrentCallsPrice)
                let tokenBytes = token.bytes
                
                let metadata = [["snet-payment-type": "prepaid-call"],
                                ["snet-payment-channel-id": channel.channelId],
                                ["snet-payment-channel-nonce": "\(nonce)" ],
                                ["snet-prepaid-auth-token-bin": tokenBytes ]]
                
                metadatapromise.fulfill(metadata)
            }
        }
    }
    
    func _getPrice() -> BigUInt {
        self._serviceClient._pricePerServiceCall * BigUInt(self._concurrencyManager.concurrentCalls)
    }
}
