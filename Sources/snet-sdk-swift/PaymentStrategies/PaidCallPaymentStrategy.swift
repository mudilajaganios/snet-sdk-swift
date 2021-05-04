//
//  PaidCallPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt

class PaidCallPaymentStrategy: BasePaidPaymentStrategy {
    
    func _generateSignature(channelId: String, nonce: BigUInt, amount: BigUInt) {
    }
    
    override func _getPrice() {
        
    }
    
    override func getPaymentMetadata() {
        let channel = self._selectChannel()
//        guard channel.state["currentSignedAmount"]
    }
}
