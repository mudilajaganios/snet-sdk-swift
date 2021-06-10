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
    
    override func getPaymentMetadata() -> Promise<[[String : Any]]> {
        return firstly {
            self._selectChannel()
        }.then({ channel -> Promise<(PaymentChannel, String)> in
            let concurrentCallsPrice = self._getPrice()
            return self._concurrencyManager.getToken(channel: channel,
                                                     serviceCallPrice: concurrentCallsPrice)
                .then { token -> Promise<(PaymentChannel, String)> in
                    return Promise.value((channel, token))
                }
        }).then { (channel, token) -> Promise<[[String : Any]]> in
            return Promise { metadatapromise in
                guard let nonce = channel.state["nonce"] else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get organization metadata"])
                    metadatapromise.reject(genericError)
                    return }
                
                let hexBytes = token.bytes
                let token64String = Data(hexBytes).base64EncodedString(options: .init(rawValue: 0))
                
                let metadata = [["snet-payment-type": "prepaid-call"],
                                ["snet-payment-channel-id": channel.channelId.description],
                                ["snet-payment-channel-nonce": nonce.description],
                                ["snet-prepaid-auth-token-bin": token64String]]
                
                metadatapromise.fulfill(metadata)
            }
        }
    }
    
    override func _getPrice() -> BigUInt {
        return self._serviceClient._pricePerServiceCall * BigUInt(self._concurrencyManager.concurrentCalls)
    }
}
