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

class Account: AccountProtocol {
    private let _web3Instance: Web3
    private let _mpeContract: MPEContractProtocol
    private var _tokenContract: DynamicContract!
    private var _ethereumAddress: EthereumAddress!
    private let _identity: PrivateKeyIdentityProtocol
    
    init(web3: Web3, networkId: String, mpeContract: MPEContractProtocol, identity: PrivateKeyIdentityProtocol) {
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
    
    func balance() -> Promise<[String: Any]> {
        let address = self._identity.getAddress()
        guard let balanceOf = self._tokenContract["balanceOf"] else {
            preconditionFailure("Balance of method not available in tokencontract")
        }
        return balanceOf(address).call()
    }
    
    func escrowBalance() -> Promise<[String: Any]> {
        let address = self.getAddress()
        return self._mpeContract.balance(of: address)
    }
    
    func depositToEscrowAccount(amountInCogs: BigUInt) -> Promise<EthereumData> {
        return firstly {
            self.allowance()
        }.then { (alreadyApprovedAmount) -> Promise<Void> in
            guard let alreadyapprovedAmt = alreadyApprovedAmount.values.first as? BigUInt else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Couldn't fetch approved amount"))
                }
            }
            if BigUInt.compare(amountInCogs, alreadyapprovedAmt) == .orderedDescending {
                return self.approveTransfer(amountInCogs: amountInCogs).asVoid()
            } else {
                return Promise.value
            }
        }.then { _ -> Promise<EthereumData> in
           return self._mpeContract.deposit(account: self, amountInCogs: amountInCogs)
        }
    }
    
    func approveTransfer(amountInCogs: BigUInt) -> Promise<EthereumData> {
        guard let approve = self._tokenContract["approve"],
              let mpeAddress = self._mpeContract.address,
              let tokenContractAddress = self._tokenContract.address else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("Couldn't get MPE contract address and token contract address"))
            }
        }
        return self.sendTransaction(toAddress: tokenContractAddress, operation: approve(mpeAddress, amountInCogs))
    }
    
    func allowance() -> Promise<[String: Any]> {
        let address = self.getAddress()
        
        guard let mpeAddress = self._mpeContract.address,
              let allowanceMethod = self._tokenContract["allowance"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("Couldn't get MPE Contract Address"))
            }
        }
        return allowanceMethod(address, mpeAddress).call()
    }
    
    func withdrawFromEscrowAccount(amountInCogs: BigUInt) -> Promise<EthereumData> {
        return self._mpeContract.withdraw(account: self, amountInCogs: amountInCogs)
    }
    
    func getAddress() -> EthereumAddress {
        return self._identity.getAddress()
    }
    
    func getSignerAddress() -> EthereumAddress {
        return self.getAddress()
    }
    
    func sign(dataToSign: String) -> String {
        return self._identity.signData(message: dataToSign)
    }
    
    func sendTransaction(toAddress: EthereumAddress, operation: SolidityInvocation) -> Promise<EthereumData> {
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
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create transaction for \(operation.method.name)"])
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
    
    deinit {
        print("Deinit Account")
    }
}
