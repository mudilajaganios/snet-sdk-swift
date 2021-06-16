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
    
    override func getPaymentMetadata(selectedChannel: Int? = nil) -> Promise<[[String : Any]]> {
        return firstly {
            self._selectChannel()
        }.then { (channel) -> Promise<[[String : Any]]> in
            return Promise { metadatapromise in
                guard let currentSignedAmount = channel.state["currentSignedAmount"],
                      let nonce = channel.state["nonce"] else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get organization metadata"])
                    metadatapromise.reject(genericError)
                    return }
                
                let amount = currentSignedAmount + self._getPrice()
                
                var signature = self._generateSignature(channelId: channel.channelId, nonce: nonce, amount: amount)
                
                let hexBytes = signature.hexToBytes()
                signature = Data(hexBytes).base64EncodedString(options: .init(rawValue: 0))
                
                let metadata = [["snet-payment-type": "escrow"],
                                ["snet-payment-channel-id": channel.channelId.description],
                                ["snet-payment-channel-nonce": nonce.description],
                                ["snet-payment-channel-amount": amount.description],
                                ["snet-payment-channel-signature-bin": signature]]
                metadatapromise.fulfill(metadata)
            }
        }
    }
    
    func _generateSignature(channelId: BigUInt, nonce: BigUInt, amount: BigUInt) -> String {
        let hexString = "__MPE_claim_message".tohexString()
            + self._serviceClient.mpeContract.address!.hex(eip55: false).replacingOccurrences(of: "0x", with: "")
            + String(channelId, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + String(nonce, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + String(amount, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        
        return self._serviceClient.sign(dataToSign: hexString)
    }
    
    override func _getPrice() -> BigUInt {
        self._serviceClient._pricePerServiceCall
    }
}
