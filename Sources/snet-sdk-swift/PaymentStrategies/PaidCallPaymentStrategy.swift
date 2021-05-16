//
//  PaidCallPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt

class PaidCallPaymentStrategy: BasePaidPaymentStrategy {
    
    override func getPaymentMetadata() -> [[String : Any]] {
        guard let channel = self._selectChannel(),
              let currentSignedAmount = channel.state["currentSignedAmount"] as? Int,
              let nonce = channel.state["nonce"] as? Int else { return [] }
        
        let amount = BigUInt(currentSignedAmount) + self._getPrice()
        
        let signature = self._generateSignature(channelId: channel.channelId, nonce: BigUInt(nonce), amount: amount)
        
        let metadata = [["snet-payment-type": "escrow"],
                        ["snet-payment-channel-id": channel.channelId],
                        ["snet-payment-channel-nonce": "\(nonce)" ],
                        ["snet-payment-channel-amount": amount ],
                        ["snet-payment-channel-signature-bin": signature ]]
        
        return metadata
    }
    
    func _generateSignature(channelId: String, nonce: BigUInt, amount: BigUInt) -> String {
        return self._serviceClient.sign([ DataToSign(t: "string", v: "__MPE_claim_message" ),
                                              DataToSign(t: "address", v: self._serviceClient.mpeContract.address?.hex(eip55: true) ),
                                              DataToSign(t: "uint256", v: channelId),
                                              DataToSign(t: "uint256", v: nonce),
                                              DataToSign(t: "uint256", v: amount)])
    }
    
    override func _getPrice() -> BigUInt {
        self._serviceClient._pricePerServiceCall
    }
}
