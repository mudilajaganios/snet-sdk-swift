//
//  MPEContract.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 10/04/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import snet_contracts

public class MPEContract {
    
    private let _web3Instance: Web3
    private let _networkId: String
    private var _mpeContract: DynamicContract!
    private var _ethereumAddress: EthereumAddress?
    
    init(web3: Web3, networkId: String) {
        self._web3Instance = web3
        self._networkId = networkId
        
        let networkAddress = SNETContracts.shared.getNetworkAddress(networkId: networkId, contractType: .mpe)

        guard let mpeContractData = SNETContracts.shared.abiContract(contractType: .mpe) else {
            return
        }

        self._ethereumAddress = EthereumAddress(hexString: networkAddress)
        self._mpeContract = try? self._web3Instance.eth.Contract(json: mpeContractData,
                                                                 abiKey: nil,
                                                                 address: self._ethereumAddress)
    }
    
    public var contract: DynamicContract {
        return self._mpeContract!
    }
    
    ///Public address of the MPE contract
    public var address: EthereumAddress? {
        return self._mpeContract?.address
    }
    
    public func balance(of address: EthereumAddress) -> Promise<[String: Any]>? {
        return self._mpeContract?["balances"]!(address).call()
    }
    
    public func deposit(account: Account, amountInCogs: BigUInt) {
        amountInCogs.description
    }
    
    public func withdraw(account: Account, amountInCogs: BigUInt) {
    }
    
    public func openChannel(account: Account, service: ServiceClient, amountInCogs: BigUInt, expiry: BigUInt) {
    }
    
    public func depositAndOpenChannel(account: Account, service: ServiceClient, amountInCogs: BigUInt, expiry: BigUInt) {
    }
    
    public func channelAddFunds(account: Account, channelId: String, amountInCogs: BigUInt) {
    }
    
    public func channelExtend(account: Account, channelId: String, expiry: BigUInt) {
    }
    
    public func channelExtendAndAddFunds(account: Account, channelId: String, expiry: BigUInt, amountInCogs: BigUInt) {
        
    }
    
    public func channelClaimTimeout(account: Account, channelId: String) {
        
    }
    
    public func channels(channelId: String) {
        
    }
    
    public func getPastOpenChannels(account: Account, service: ServiceClient, startingBlockNumber: BigUInt?) {
//        var fromBlock = startingBlockNumber ?? self._deploymentBlockNumber()
    }
    
    //MARK: Private methods
    
    private func _fundEscrowAccount(account: Account, amountInCogs: Double) {
//        let currentEscrowBalance = self.balance(of: <#T##EthereumAddress#>)
    }
    
    private func _deploymentBlockNumber() -> BigUInt? {
        var blockNumber: BigUInt?
        let networks = SNETContracts.shared.getNetworks(networkId: self._networkId, contractType: .mpe)
        guard let transactionHash = networks["transactionHash"] as? String else {
            return blockNumber
        }
        firstly {
            self._web3Instance.eth.getTransactionReceipt(transactionHash: EthereumData(transactionHash.bytes))
        }.done { receiptObject in
            guard let receipt = receiptObject else { return }
            blockNumber = receipt.blockNumber.quantity
        }
        return blockNumber
    }
}
