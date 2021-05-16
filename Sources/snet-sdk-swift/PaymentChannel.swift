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
    
    public func addFunds(amount: BigUInt) -> Promise<EthereumData> {
        return self._mpeContract.channelAddFunds(account: self._account, channelId: self._channelId, amountInCogs: amount)
    }
    
    public func extend(expiry: BigUInt) -> Promise<EthereumData> {
        return self._mpeContract.channelExtend(account: self._account, channelId: self._channelId, expiry: expiry)
    }
    
    public func extendAndAddFunds(expiry: BigUInt, amount: BigUInt) -> Promise<EthereumData> {
        return self._mpeContract.channelExtendAndAddFunds(account: self._account, channelId: self._channelId, expiry: expiry, amountInCogs: amount)
    }
    
    public func claimUnusedTokens() -> Promise<EthereumData> {
        return self._mpeContract.channelClaimTimeout(account: self._account, channelId: self._channelId)
    }
    
    public func syncState() -> Promise<PaymentChannel> {
        let latestChannelInfoOnBlockchain = self._mpeContract.channels(channelId: self._channelId)
        guard let currentState = self._currentChannelState() else {
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        self._state["nonce"] = currentState.nonce
        self._state["currentNonce"] = currentState.nonce
        self._state["expiry"] = 0
        self._state["amountDeposited"] = 0
        self._state["currentSignedAmount"] = 0
        self._state["availableAmount"] = 0
        
        return Promise { state in
            state.fulfill(self)
        }
    }
    
    fileprivate func _currentChannelState() -> (currentSignedAmount: BigUInt, nonce: BigUInt)? {
        guard let channelStateReply = self._serviceClient.getChannelState(channelId: self._channelId) else { return nil }
        let nonce = channelStateReply.currentNonce
        let currentSignedAmount = channelStateReply.currentSignedAmount
        let channelState = (currentSignedAmount: BigUInt(currentSignedAmount), nonce: BigUInt(nonce))
        return channelState
    }
}
