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

struct PaymentChannelState {
    let nonce: BigUInt
    let currentSignedAmount: BigUInt
    let plannedAmount: BigUInt
    let usedAmount: BigUInt
}

class PaymentChannel {
    
    private let _web3Instance: Web3
    private let _channelId: BigUInt
    private let _mpeContract: MPEContractProtocol
    private let _account: AccountProtocol
    private let _serviceClient: ServiceClientStateProtocol
    private var _state: [String: BigUInt]
    
    init(channelId: BigUInt, web3: Web3, account: AccountProtocol, service: ServiceClientStateProtocol, mpeContract: MPEContractProtocol) {
        self._channelId = channelId
        self._web3Instance = web3
        self._account = account
        self._serviceClient = service
        self._mpeContract = mpeContract
        self._state = ["nonce": 0,
                       "currentSignedAmount": 0]
    }
    
    public var channelId: BigUInt {
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
        let channelInfo = self._mpeContract.channels(channelId: self._channelId)
        let currentStatePromise = self._currentChannelState()
        return firstly {
            when(fulfilled: channelInfo, currentStatePromise)
        }.then { (latestChannelInfoOnBlockchain, currentState) -> Promise<PaymentChannel> in
            guard let nonce = latestChannelInfoOnBlockchain["nonce"] as? BigUInt,
                  let expiry = latestChannelInfoOnBlockchain["expiration"] as? BigUInt,
                  let amountDeposited = latestChannelInfoOnBlockchain["value"] as? BigUInt else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Channel Info on Blockchain is incomplete/ invalid"))
                }
            }
            
            let availableAmount = amountDeposited - currentState.currentSignedAmount
            self._state["nonce"] = nonce
            self._state["currentNonce"] = currentState.nonce
            self._state["expiry"] = expiry
            self._state["amountDeposited"] = amountDeposited
            self._state["currentSignedAmount"] = currentState.currentSignedAmount
            self._state["availableAmount"] = availableAmount
            self._state["plannedAmount"] = currentState.plannedAmount
            self._state["usedAmount"] = currentState.usedAmount
            
            return Promise { state in
                state.fulfill(self)
            }
        }
    }
    
    fileprivate func _currentChannelState() -> Promise<PaymentChannelState> {
        return firstly {
            self._serviceClient.getChannelState(channelId: self._channelId)
        }.then { channelStateReply -> Promise<PaymentChannelState> in
            let nonce = channelStateReply.currentNonce
            let currentSignedAmount = channelStateReply.currentSignedAmount
            let channelState = PaymentChannelState(nonce: BigUInt(nonce),
                                                   currentSignedAmount: BigUInt(currentSignedAmount),
                                                   plannedAmount: try! BigUInt(channelStateReply.plannedAmount),
                                                   usedAmount: try! BigUInt(channelStateReply.usedAmount))
            
            return Promise<PaymentChannelState>.value(channelState)
        }
    }
}
