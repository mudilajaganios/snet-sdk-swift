//
//  PaidCallPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt
import PromiseKit

class PaidCallPaymentStrategy: BasePaidPaymentStrategy {
    
    func getPaymentMetadata() -> Promise<[[String : Any]]> {
        return firstly {
            self._selectChannel()
        }.then { (channel) -> Promise<[[String : Any]]> in
            return Promise { metadatapromise in
                guard let currentSignedAmount = channel.state["currentSignedAmount"] as? Int,
                      let nonce = channel.state["nonce"] as? Int else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get organization metadata"])
                    metadatapromise.reject(genericError)
                    return }
                
                let amount = BigUInt(currentSignedAmount) + self._getPrice()
                
                let signature = self._generateSignature(channelId: channel.channelId, nonce: BigUInt(nonce), amount: amount)
                
                let metadata = [["snet-payment-type": "escrow"],
                                ["snet-payment-channel-id": channel.channelId],
                                ["snet-payment-channel-nonce": "\(nonce)" ],
                                ["snet-payment-channel-amount": amount ],
                                ["snet-payment-channel-signature-bin": signature ]]
                metadatapromise.fulfill(metadata)
            }
        }
    }
    
    func _generateSignature(channelId: String, nonce: BigUInt, amount: BigUInt) -> Data {
        return self._serviceClient.sign([ DataToSign(t: "string", v: "__MPE_claim_message" ),
                                              DataToSign(t: "address", v: self._serviceClient.mpeContract.address?.hex(eip55: true) ),
                                              DataToSign(t: "uint256", v: channelId),
                                              DataToSign(t: "uint256", v: nonce),
                                              DataToSign(t: "uint256", v: amount)])
    }
    
    func _getPrice() -> BigUInt {
        self._serviceClient._pricePerServiceCall
    }
}
