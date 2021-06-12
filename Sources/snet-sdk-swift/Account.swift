//
//  Account.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 12/04/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import PromiseKit
import snet_contracts
import CryptoSwift

public final class Account {
    
    private let _web3Instance: Web3
    private unowned let _mpeContract: MPEContract
    private var _tokenContract: DynamicContract!
    private var _ethereumAddress: EthereumAddress!
    private let _identity: PrivateKeyIdentity
    
    init(web3: Web3, networkId: String, mpeContract: MPEContract, identity: PrivateKeyIdentity) {
        self._web3Instance = web3
        self._mpeContract = mpeContract
        self._identity = identity
        
        let networkAddress = SNETContracts.shared.getNetworkAddress(networkId: networkId, contractType: .agitoken)

        guard let tokenContractData = SNETContracts.shared.abiContract(contractType: .agitoken) else {
            return
        }

        let ethereumAddress = EthereumAddress(hexString: networkAddress)
        self._ethereumAddress = ethereumAddress
        guard let tokenContract = try? self._web3Instance.eth.Contract(json: tokenContractData,
                                                                   abiKey: nil,
                                                                   address: ethereumAddress) else {
            preconditionFailure("Unable to create token contract")
        }
        self._tokenContract = tokenContract
    }
    
    public func balance() -> Promise<[String: Any]> {
        let address = self._identity.getAddress()
        return self._tokenContract["balanceOf"]!(address).call()
    }
    
    public func escrowBalance() -> Promise<[String: Any]> {
        let address = self.getAddress()
        return self._mpeContract.balance(of: address)
    }
    
    
    public func depositToEscrowAccount(amountInCogs: BigUInt) -> Promise<EthereumData> {
        return firstly {
            self.allowance()
        }.then { (alreadyApprovedAmount) -> Promise<EthereumData> in
            guard let alreadyapprovedAmt = alreadyApprovedAmount[""] as? BigUInt else {
                return Promise { error in
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                }
            }
            if amountInCogs > alreadyapprovedAmt {
                return self.approveTransfer(amountInCogs: amountInCogs)
            } else {
                return Promise { none in
                    guard let noneData = try? EthereumData(ethereumValue: EthereumValue(true)) else {
                        let genericError = NSError(
                            domain: "snet-sdk",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                        none.reject(genericError)
                        return
                    }
                    none.fulfill(noneData)
                }
            }
        }.then { (_) -> Promise<EthereumData> in
           return self._mpeContract.deposit(account: self, amountInCogs: amountInCogs)
        }
    }
    
    public func approveTransfer(amountInCogs: BigUInt) -> Promise<EthereumData> {
        guard let approve = self._tokenContract["approve"],
              let mpeAddress = self._mpeContract.address,
              let tokenContractAddress = self._tokenContract.address else {
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return self.sendTransaction(toAddress: tokenContractAddress, operation: approve(mpeAddress, amountInCogs))
    }
    
    public func allowance() -> Promise<[String: Any]> {
        let address = self.getAddress()
        guard let mpeAddress = self._mpeContract.address else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return self._tokenContract["allowance"]!(address, mpeAddress).call()
    }
    
    public func withdrawFromEscrowAccount(amountInCogs: BigUInt) -> Promise<EthereumData> {
        return self._mpeContract.withdraw(account: self, amountInCogs: amountInCogs)
    }
    
    public func getAddress() -> EthereumAddress {
        return self._identity.getAddress()
    }
    
    public func getSignerAddress() -> EthereumAddress {
        return self.getAddress()
    }
    
    func sign(dataToSign: String) -> String {
        return self._identity.signData(message: dataToSign)
    }
    
    public func sendTransaction(toAddress: EthereumAddress, operation: SolidityInvocation) -> Promise<EthereumData> {
        let address = self.getAddress()
        let gasPricePromise = self._web3Instance.eth.gasPrice()
        let gasLimitPromise = operation.estimateGas(from: address)
        let noncePromise = self._transactionCount()
        
        return firstly {
            when(fulfilled: gasPricePromise, gasLimitPromise, noncePromise)
        }.then { (gasPrice, gasLimit, nonce) -> Promise<EthereumData> in
            guard let transaction = operation.createTransaction(nonce: nonce,
                                                                 from: address,
                                                                 value: 0,
                                                                 gas: gasLimit,
                                                                 gasPrice: gasPrice) else {
                return Promise { error in
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                }
            }
            return self._identity.sendTransaction(transactionObject: transaction)
        }
    }
    
    private func _transactionCount() -> Promise<EthereumQuantity> {
        let address = self.getAddress()
        return self._web3Instance.eth.getTransactionCount(address: address, block: .latest)
    }
}
