//
//  BasePaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt

class BasePaidPaymentStrategy: PaymentChannelProtocol {
    
    let _serviceClient: ServiceClient
    let _blockOffset: Int
    let _callAllowance: Int
    
    init(serviceClient: ServiceClient, blockOffset: Int = 240, callAllowance: Int = 1) {
        self._serviceClient = serviceClient;
        self._blockOffset = blockOffset;
        self._callAllowance = callAllowance;
    }
    
    func _selectChannel() -> PaymentChannel {
        let account = self._serviceClient.account
        self._serviceClient.loadOpenChannels()
        self._serviceClient.updateChannelStates()
        let paymentChannels = self._serviceClient.paymentChannels
        let serviceCallPrice = self._getPrice()
        let extendChannelFund = serviceCallPrice * self._callAllowance
        let mpeBalance = account.escrowBalance()
        let defaultExpiration = self._serviceClient.defaultChannelExpiration()
        let extendedExpiry = defaultExpiration + self._blockOffset
        
        var selectedPaymentChannel: PaymentChannel?
        
        if paymentChannels.count < 1 {
            if serviceCallPrice > mpeBalance {
                selectedPaymentChannel = self._serviceClient.depositAndOpenChannel(amount: serviceCallPrice, expiry: extendedExpiry)
            } else {
                selectedPaymentChannel = self._serviceClient.openChannel(amount: serviceCallPrice, expiry: extendedExpiry)
            }
        } else {
            selectedPaymentChannel = paymentChannels.first
        }
        
        let hasSufficientFunds = self._doesChannelHaveSufficientFunds(channel: selectedPaymentChannel!, requiredAmount: serviceCallPrice)
        let isValidChannel = self._isValidChannel(channel: selectedPaymentChannel!, expiry: defaultExpiration)
        
        if hasSufficientFunds && !isValidChannel {
            selectedPaymentChannel?.extend(expiry: extendedExpiry)
        } else if !hasSufficientFunds && isValidChannel {
            selectedPaymentChannel?.addFunds(amount: extendChannelFund)
        } else if !hasSufficientFunds && !isValidChannel {
            selectedPaymentChannel?.extendAndAddFunds(expiry: extendedExpiry, amount: extendChannelFund)
        }
        
        return selectedPaymentChannel
    }
    
    func _getPrice() -> BigUInt {
        return 0
    }
    
    //TODO: Channel state to be implemented. First update in PaymentChannel class
    func _doesChannelHaveSufficientFunds(channel: PaymentChannel, requiredAmount: BigUInt) -> Bool {
        return true
    }
    
    //TODO: Channel state to be implemented. First update in PaymentChannel class
    func _isValidChannel(channel: PaymentChannel, expiry: BigUInt) -> Bool {
        return true
    }
    
    func getPaymentMetadata() {
        
    }
}
