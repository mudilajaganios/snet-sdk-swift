//
//  PrivateKeyIdentity.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 13/04/2021.
//

import Foundation
import Web3
import Web3PromiseKit
import PromiseKit

class PrivateKeyIdentity {
    
    private let _privateKey: String
    private let _web3: Web3
    
    init(config: SDKConfig, web3: Web3) {
        self._web3 = web3
        self._privateKey = config.privateKey
        self._setupAccount()
    }
    
    public func getAddress() {
//        return self._web3.eth.
    }
    
    public func signData(sha3Message: Any) {
    }
    
    public func sendTransaction(transactionObject: Any) {
//        self._signTransaction(txObject: transactionObject)
//        self._web3.eth.sendTransaction(transaction: <#T##EthereumTransaction#>)
    }
    
    private func _signTransaction(txObject: Any) {
//        EthereumSignedTransaction(nonce: 0, gasPrice: 0, gasLimit: 0, to: nil, value: 0, data: EthereumDat, v: <#T##EthereumQuantity#>, r: <#T##EthereumQuantity#>, s: <#T##EthereumQuantity#>, chainId: <#T##EthereumQuantity#>)
    }
    
    private func _setupAccount() {
        firstly {
            self._web3.eth.accounts()
        }.done { (accounts) in
//            let account = accounts[0].
        }
        
    }
}
