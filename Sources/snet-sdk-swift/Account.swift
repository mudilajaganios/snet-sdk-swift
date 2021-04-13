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

public final class Account {
    
    private let _web3Instance: Web3
    private var _mpeContract: DynamicContract?
    private var _tokenContract: DynamicContract?
    private var _ethereumAddress: EthereumAddress!
    
    init(web3: Web3, networkId: String, mpeContract: DynamicContract) {
        self._web3Instance = web3
        self._mpeContract = mpeContract
        
        let networkAddress = SNETContracts.shared.getNetworkAddress(networkId: networkId, contractType: .agitoken)

        guard let tokenContractData = SNETContracts.shared.abiContract(contractType: .agitoken) else {
            return
        }

        let ethereumAddress = EthereumAddress(hexString: networkAddress)
        self._ethereumAddress = ethereumAddress
        guard let tokenContract = try? self._web3Instance.eth.Contract(json: tokenContractData,
                                                                   abiKey: nil,
                                                                   address: ethereumAddress) else {
            return
        }
        self._tokenContract = tokenContract
    }
    
    public func balance() -> Promise<[String: Any]> {
        let address = self.getAddress()
        return self._tokenContract!["balanceOf"]!(address).call()
    }
    
//    public func escrowBalance() {
//        let address = self.getAddress()
//        return self._mpeContract.balance(address)
//    }
    
    public func depositToEscrowAccount(amountInCogs: BigUInt) {
        
    }
    
    public func approveTransfer(amountInCogs: BigUInt) {
        
    }
    
    public func allowance() {
        let address = self.getAddress()
//        return self._tokenContract!["allowance"]!(address, self._mpeContract!.address).call()
    }
    
    public func withdrawFromEscrowAccount(amountInCogs: BigUInt) {
//        return self._mpeContract.withdraw()
    }
    
    public func getAddress() -> String {
        return ""
    }
    
    public func getSignerAddress() -> String {
        return self.getAddress()
    }
    
//    public func signData(...data) {
//    }
    
//    public func sendTransaction(to, contractFn, contractFnArgs: ...String) {
//    }
    
    private func _baseTransactionObject() {
        
    }
    
    private func _getGas() {
        
    }
    
    private func _transactionCount() {
        
    }
}
