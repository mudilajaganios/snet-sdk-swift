//
//  PrepaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation

class PrepaidPaymentStrategy: BasePaidPaymentStrategy {
    
    fileprivate let _concurrencyManager: ConcurrencyManager
    
    init(serviceClient: ServiceClient, concurrencyManager: ConcurrencyManager, blockOffset: Int = 240, callAllowance: Int = 1) {
        self._concurrencyManager = concurrencyManager
        super.init(serviceClient: serviceClient, blockOffset: blockOffset, callAllowance: callAllowance)
    }
    
    override func getPaymentMetadata() {
        
    }
    
    override func _getPrice() {
        
    }
}
