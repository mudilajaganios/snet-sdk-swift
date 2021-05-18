//
//  BasePaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation
import BigInt
import Web3
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
    
    func _selectChannel() -> Promise<PaymentChannel> {
        let account = self._serviceClient.account
        let loadOpenChannels = self._serviceClient.loadOpenChannels()
        let updateChannelStates = self._serviceClient.updateChannelStates()
        let paymentChannels = self._serviceClient.paymentChannels
        let serviceCallPrice = self._getPrice()
        var mpeBalance: BigUInt = 0
        
        return firstly {
            when(fulfilled: loadOpenChannels, updateChannelStates, account.escrowBalance())
        }.then { (_ ,_ , escrowbalance) -> Promise<PaymentChannel> in
            guard let mpeBalance = escrowbalance.values.first as? BigUInt else {
                return Promise { error in
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                }
            }
            
            let defaultExpiration = self._serviceClient.defaultChannelExpiration()
            let extendedExpiry = defaultExpiration + self._blockOffset
            
            let promise: Promise<PaymentChannel>?
            
            if paymentChannels.count < 1 {
                if BigUInt.compare(serviceCallPrice, mpeBalance) == .orderedDescending {
                    promise = self._serviceClient.depositAndOpenChannel(amount: serviceCallPrice, expiry: extendedExpiry)
                } else {
                    promise = self._serviceClient.openChannel(amount: serviceCallPrice, expiry: extendedExpiry)
                }
                
                guard let promise = promise else {
                    return Promise { error in
                        let genericError = NSError(
                            domain: "snet-sdk",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                        error.reject(genericError)
                    }
                }
                
                return promise.then({ (channel) -> Promise<PaymentChannel> in
                    return self._getselectedPaymentChannel(selectedPaymentChannel: channel)
                })
            } else {
                guard let paymentChannel = paymentChannels.first else {
                    return Promise { error in
                        let genericError = NSError(
                            domain: "snet-sdk",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                        error.reject(genericError)
                    }
                }
                return self._getselectedPaymentChannel(selectedPaymentChannel: paymentChannel)
            }
        }
    }
    
    private func _getselectedPaymentChannel(selectedPaymentChannel: PaymentChannel) -> Promise<PaymentChannel> {
        let defaultExpiration = self._serviceClient.defaultChannelExpiration()
        let extendedExpiry = defaultExpiration + self._blockOffset
        let serviceCallPrice = self._getPrice()
        let extendChannelFund = serviceCallPrice * self._callAllowance
        
        let hasSufficientFunds = self._doesChannelHaveSufficientFunds(channel: selectedPaymentChannel, requiredAmount: serviceCallPrice)
        let isValidChannel = self._isValidChannel(channel: selectedPaymentChannel, expiry: defaultExpiration)
        
        var promise: Promise<EthereumData>?
        
        if hasSufficientFunds && !isValidChannel {
            promise = selectedPaymentChannel.extend(expiry: extendedExpiry)
        } else if !hasSufficientFunds && isValidChannel {
            promise = selectedPaymentChannel.addFunds(amount: extendChannelFund)
        } else if !hasSufficientFunds && !isValidChannel {
            promise = selectedPaymentChannel.extendAndAddFunds(expiry: extendedExpiry, amount: extendChannelFund)
        }
        
        guard let promise = promise else {
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        
        return promise.then({(_) -> Promise<PaymentChannel> in
            return Promise { channel in
                channel.fulfill(selectedPaymentChannel)
            }
        })
    }
    
    func _doesChannelHaveSufficientFunds(channel: PaymentChannel, requiredAmount: BigUInt) -> Bool {
        guard let availableamount = channel.state["availableAmount"] else { return false }
        return BigUInt.compare(availableamount, requiredAmount) == .orderedSame || BigUInt.compare(availableamount, requiredAmount) == .orderedDescending
    }
    
    func _isValidChannel(channel: PaymentChannel, expiry: BigUInt) -> Bool {
        guard let channelexpiry = channel.state["expiry"] else { return false }
        return BigUInt.compare(channelexpiry, expiry) == .orderedSame || BigUInt.compare(channelexpiry, expiry) == .orderedDescending
    }
}
