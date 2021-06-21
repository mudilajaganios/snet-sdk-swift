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

class PrivateKeyIdentity: PrivateKeyIdentityProtocol {
    
    private let _privateKey: String
    private let _web3: Web3
    private var _defaultAccount: EthereumAddress!
    private let _chainId: EthereumQuantity
    
    init(config: SDKConfig, web3: Web3) {
        self._web3 = web3
        self._privateKey = config.privateKey
        
        if let chainId = try? EthereumQuantity(config.networkId) {
            self._chainId =  chainId
        } else {
            self._chainId = EthereumQuantity(integerLiteral: 0)
        }
        
        self._setupAccount()
    }
    
    func getAddress() -> EthereumAddress {
        return self._defaultAccount
    }
    
    func signData(message: String) -> String {
        return self.privateKey?.signData(message: message) ?? ""
    }
    
    func sendTransaction(transactionObject: EthereumTransaction) -> Promise<EthereumData> {
        do {
            let signedTransaction = try transactionObject.signX(with: self.privateKey!, chainId: _web3.properties.rpcId)

            return firstly {
                self._web3.eth.sendRawTransaction(transaction: signedTransaction)
            }.then { transactionHash -> Promise<EthereumTransactionReceiptObject?> in
                return self._getTransactionStatus(transactionHash: transactionHash)
            }.then { receiptObject -> Promise<EthereumData> in
                guard let status = receiptObject?.status?.quantity, status == 1,
                      let transactionHash = receiptObject?.transactionHash else {
                    return Promise { error in
                        let genericError = NSError(
                            domain: "snet-sdk",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get transaction hash"])
                        error.reject(genericError)
                    }
                }

                return Promise<EthereumData>.value(transactionHash)
            }
        } catch {
            print("Failed to sign the transaction.")
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Could not sign the transaction"])
                error.reject(genericError)
            }
        }
    }
    
    private func _getTransactionStatus(transactionHash: EthereumData) -> Promise<EthereumTransactionReceiptObject?> {
        return self._web3.eth.getTransactionReceipt(transactionHash: transactionHash)
            .recover { error -> Promise<EthereumTransactionReceiptObject?> in
                if let error = error as? Web3Response<EthereumTransactionReceiptObject?>.Error,
                   error.localizedDescription == Web3Response<EthereumTransactionReceiptObject?>.Error.emptyResponse.localizedDescription
                {
                    print("Waiting for the transaction status (Success/ Fail) for \(transactionHash.hex())")
                    return self._getTransactionStatus(transactionHash: transactionHash)
                } else {
                    print("Transaction \(transactionHash.hex()) failed with \(error.localizedDescription)")
                    return Promise { error in
                        let genericError = NSError(
                            domain: "snet-sdk",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Transaction failed"])
                        error.reject(genericError)
                    }
                }
            }
    }
    
    private func _setupAccount() {
        guard let privateKey = self.privateKey else { return }
        self._defaultAccount = privateKey.address
    }
    
    private var privateKey: EthereumPrivateKey? {
        return try? EthereumPrivateKey(hexPrivateKey: self._privateKey)
    }
}
