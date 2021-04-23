//
//  DefaultPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 21/04/2021.
//

import Foundation

class DefaultPaymentStrategy {
    
    fileprivate let _concurrentCalls: Bool
    
    init(concurrentCalls: Bool = true) {
        self._concurrentCalls = concurrentCalls
    }
    
    func getPaymentMetadata(serviceClient: ServiceClient) {
        let freecallPaymentStrategy = FreeCallPaymentStrategy(serviceClient: serviceClient)
        let isfreeCallAvailable = freecallPaymentStrategy.isFreeCallAvailable()
        
//        var <#name#> = <#value#>
        
        
        if isfreeCallAvailable {
            freecallPaymentStrategy.getPaymentMetadata()
        } else if serviceClient.concurrencyFlag {
            let concurrencyManager = ConcurrencyManager(concurrentCalls: self._concurrentCalls, serviceClient: serviceClient)
            let paymentStrategy = PrepaidPaymentStrategy(serviceClient: serviceClient, concurrencyManager: concurrencyManager)
            paymentStrategy.getPaymentMetadata()
        } else {
            let paymentStrategy = PaidCallPaymentStrategy(serviceClient: serviceClient)
            paymentStrategy.getPaymentMetadata()
        }
    }
}
