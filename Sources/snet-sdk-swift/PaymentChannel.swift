//
//  PaymentChannel.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 18/04/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit

class PaymentChannel {
    
    private let _web3Instance: Web3
    private let _channelId: String
    private unowned let _mpeContract: MPEContract
    private unowned let _account: Account
    private unowned let _serviceClient: ServiceClient
    private var _state: [String: BigUInt]
    
    init(channelId: String, web3: Web3, account: Account, service: ServiceClient, mpeContract: MPEContract) {
        self._channelId = channelId
        self._web3Instance = web3
        self._account = account
        self._serviceClient = service
        self._mpeContract = mpeContract
        self._state = ["nonce": 0,
                       "currentSignedAmount": 0]
    }
    
    public var channelId: String {
        return self._channelId
    }
    
    public var state: [String: BigUInt] {
        return self._state
    }
    
    public func addFunds(amount: BigUInt) {
        self._mpeContract.channelAddFunds(account: self._account, channelId: self._channelId, amountInCogs: amount)
    }
    
    public func extend(expiry: BigUInt) {
        self._mpeContract.channelExtend(account: self._account, channelId: self._channelId, expiry: expiry)
    }
    
    public func extendAndAddFunds(expiry: BigUInt, amount: BigUInt) {
        self._mpeContract.channelExtendAndAddFunds(account: self._account, channelId: self._channelId, expiry: expiry, amountInCogs: amount)
    }
    
    public func claimUnusedTokens() {
        self._mpeContract.channelClaimTimeout(account: self._account, channelId: self._channelId)
    }
}
