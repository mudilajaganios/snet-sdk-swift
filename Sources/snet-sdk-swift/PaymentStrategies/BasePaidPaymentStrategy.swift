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
    func getPaymentMetadata(selectedChannel: Int? = nil) -> Promise<[[String : Any]]> {
        return Promise.value([])
    }
    
    let _serviceClient: ServiceClient
    let _blockOffset: BigUInt
    let _callAllowance: BigUInt
    
    init(serviceClient: ServiceClient, blockOffset: BigUInt = 240, callAllowance: BigUInt = 1) {
        self._serviceClient = serviceClient;
        self._blockOffset = blockOffset;
        self._callAllowance = callAllowance;
    }
    
    func _selectChannel(_preselectedChannel: Int? = nil) -> Promise<PaymentChannel> {
        let account = self._serviceClient.account
        let serviceCallPrice = self._getPrice()
        
        return firstly {
            self._serviceClient.loadOpenChannels()
        }.then { _ -> Promise<[PaymentChannel]> in
            self._serviceClient.updateChannelStates()
        }.then { _ -> Promise<[String: Any]> in
            account.escrowBalance()
        }.then { escrowbalance -> Promise<(BigUInt, BigUInt)> in
            guard let mpeBalance = escrowbalance.values.first as? BigUInt else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Failed to select channel. Escrow balance is not available"))
                }
            }
            return self._serviceClient.defaultChannelExpiration().then { defaultExpiration -> Promise<(BigUInt, BigUInt)> in
                return Promise<(BigUInt, BigUInt)>.value((mpeBalance, defaultExpiration))
            }
        }.then { (mpeBalance, defaultExpiration) -> Promise<PaymentChannel> in
            let extendedExpiry = defaultExpiration + self._blockOffset
            
            if let selectedChannelId = _preselectedChannel,
               let selectedChannel = self._serviceClient.paymentChannels.first(where: { $0.channelId == selectedChannelId }) {
                print("Info: Returning a preselected payment channel")
                return Promise<PaymentChannel>.value(selectedChannel)
            }
            
            if self._serviceClient.paymentChannels.count < 1 {
                print("Info: No existing payment channels, Opening a new channel")
                let promise: Promise<PaymentChannel>
                if BigUInt.compare(serviceCallPrice, mpeBalance) == .orderedDescending {
                    promise = self._serviceClient.depositAndOpenChannel(amount: serviceCallPrice, expiry: extendedExpiry)
                } else {
                    promise = self._serviceClient.openChannel(amount: serviceCallPrice, expiry: extendedExpiry)
                }
                
                return promise.then({ (channel) -> Promise<PaymentChannel> in
                    return self._getselectedPaymentChannel(selectedPaymentChannel: channel)
                })
            } else {
                print("Info: Selecting an available payment channel")
                guard let paymentChannel = self._serviceClient.paymentChannels.first else {
                    return Promise { error in
                        error.reject(SnetError.dataNotAvailable("Couldn't fetch a payment channel"))
                    }
                }
                return self._getselectedPaymentChannel(selectedPaymentChannel: paymentChannel)
            }
        }
    }
    
    private func _getselectedPaymentChannel(selectedPaymentChannel: PaymentChannel) -> Promise<PaymentChannel> {
        return firstly {
            self._serviceClient.defaultChannelExpiration()
        }.then { defaultExpiration -> Promise<PaymentChannel> in
            let extendedExpiry = defaultExpiration + self._blockOffset
            let serviceCallPrice = self._getPrice()
            let extendChannelFund = serviceCallPrice * self._callAllowance
            
            let hasSufficientFunds = self._doesChannelHaveSufficientFunds(channel: selectedPaymentChannel, requiredAmount: serviceCallPrice)
            let isValidChannel = self._isValidChannel(channel: selectedPaymentChannel, expiry: defaultExpiration)
            
            var promise: Promise<EthereumData>?
            
            if hasSufficientFunds && !isValidChannel {
                print("Info: Extending channel's expiry")
                promise = selectedPaymentChannel.extend(expiry: extendedExpiry)
            } else if !hasSufficientFunds && isValidChannel {
                print("Info: Adding funds to a channel")
                promise = selectedPaymentChannel.addFunds(amount: extendChannelFund)
            } else if !hasSufficientFunds && !isValidChannel {
                print("Info: Adding funds and extending the expiry of a channel")
                promise = selectedPaymentChannel.extendAndAddFunds(expiry: extendedExpiry, amount: extendChannelFund)
            }
            
            guard let promise = promise else {
                return Promise<PaymentChannel>.value(selectedPaymentChannel)
            }
            
            return promise.then({(_) -> Promise<PaymentChannel> in
                return Promise<PaymentChannel>.value(selectedPaymentChannel)
            })
        }
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
}
