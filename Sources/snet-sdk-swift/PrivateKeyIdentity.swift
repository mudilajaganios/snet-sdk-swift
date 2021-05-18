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
    private var _defaultAccount: EthereumAddress!
    
    init(config: SDKConfig, web3: Web3) {
        self._web3 = web3
        self._privateKey = config.privateKey
        self._setupAccount()
    }
    
    public func getAddress() -> EthereumAddress {
        return self._defaultAccount
    }
    
    //TODO: Sign the message against private key
    public func signData(sha3Message: Array<UInt8>) -> Data {
        return Data()
    }
    
    public func sendTransaction(transactionObject: EthereumTransaction) -> Promise<EthereumData> {
        guard let privateKey = try? EthereumPrivateKey(hexPrivateKey: "0x" + self._privateKey),
              let signedTransaction = try? transactionObject.sign(with: privateKey) else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return self._web3.eth.sendRawTransaction(transaction: signedTransaction)
    }
    
    private func _setupAccount() {
        guard let privateKey = try? EthereumPrivateKey(hexPrivateKey: "0x" + self._privateKey) else { return }
        self._defaultAccount = privateKey.address
    }
}
