//
//  DefaultPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 21/04/2021.
//

import Foundation
import PromiseKit
import BigInt

class DefaultPaymentStrategy: PaymentStrategyProtocol {
    
    var selectedChannelId: Int
    
    var _concurrentCalls: Int
    
    required init(concurrentCalls: Int = 1) {
        self._concurrentCalls = concurrentCalls
        self.selectedChannelId = 0
    }
    
    func getPaymentMetadata(serviceClient: ServiceClientProtocol) -> Promise<[[String : Any]]> {
        let serviceClient = serviceClient as! ServiceClient
        let freecallPaymentStrategy = FreeCallPaymentStrategy(serviceClient: serviceClient)
        return firstly {
            freecallPaymentStrategy.isFreeCallAvailable()
        }.then { isfreeCallAvailable -> Promise<[[String : Any]]> in
            if isfreeCallAvailable {
                return freecallPaymentStrategy.getPaymentMetadata()
            } else if serviceClient.concurrencyFlag {
                let concurrencyManager = ConcurrencyManager(concurrentCalls: self._concurrentCalls, serviceClient: serviceClient)
                let paymentStrategy = PrepaidPaymentStrategy(serviceClient: serviceClient, concurrencyManager: concurrencyManager)
                return paymentStrategy.getPaymentMetadata(selectedChannel: self.selectedChannelId)
            } else {
                let paymentStrategy = PaidCallPaymentStrategy(serviceClient: serviceClient)
                return paymentStrategy.getPaymentMetadata()
            }
        }
    }
}
