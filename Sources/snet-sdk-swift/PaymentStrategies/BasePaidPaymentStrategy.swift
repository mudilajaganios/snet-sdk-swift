//
//  BasePaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt
import PromiseKit

class BasePaidPaymentStrategy: PaymentChannelProtocol {
    
    let _serviceClient: ServiceClient
    let _blockOffset: BigUInt
    let _callAllowance: BigUInt
    
    init(serviceClient: ServiceClient, blockOffset: BigUInt = 240, callAllowance: BigUInt = 1) {
        self._serviceClient = serviceClient;
        self._blockOffset = blockOffset;
        self._callAllowance = callAllowance;
    }
    
    func _selectChannel() -> PaymentChannel? {
        let account = self._serviceClient.account
        self._serviceClient.loadOpenChannels()
        self._serviceClient.updateChannelStates()
        let paymentChannels = self._serviceClient.paymentChannels
        let serviceCallPrice = self._getPrice()
        let extendChannelFund = serviceCallPrice * self._callAllowance
        var mpeBalance: BigUInt = 0
            
        firstly {
            account.escrowBalance()
        }.done { escrowbalance in
            mpeBalance = escrowbalance["balance"] as! BigUInt
        }
        
        let defaultExpiration = self._serviceClient.defaultChannelExpiration()
        let extendedExpiry = defaultExpiration + self._blockOffset
        
        var selectedPaymentChannel: PaymentChannel?
        
//        if paymentChannels.count < 1 {
//            if BigUInt.compare(serviceCallPrice, mpeBalance) == .orderedDescending {
//                selectedPaymentChannel = self._serviceClient.depositAndOpenChannel(amount: serviceCallPrice, expiry: extendedExpiry)
//            } else {
//                selectedPaymentChannel = self._serviceClient.openChannel(amount: serviceCallPrice, expiry: extendedExpiry)
//            }
//        } else {
//            selectedPaymentChannel = paymentChannels.first
//        }
        
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
    
    func _doesChannelHaveSufficientFunds(channel: PaymentChannel, requiredAmount: BigUInt) -> Bool {
        guard let availableamount = channel.state["availableAmount"] else { return false }
        return BigUInt.compare(availableamount, requiredAmount) == .orderedSame || BigUInt.compare(availableamount, requiredAmount) == .orderedDescending
    }
    
    func _isValidChannel(channel: PaymentChannel, expiry: BigUInt) -> Bool {
        guard let channelexpiry = channel.state["expiry"] else { return false }
        return BigUInt.compare(channelexpiry, expiry) == .orderedSame || BigUInt.compare(channelexpiry, expiry) == .orderedDescending
    }
    
    func _getPrice() -> BigUInt {
        return 0
    }
    
    func getPaymentMetadata() -> [[String: Any]] {
        return []
    }
}
