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

public final class MPEContract {
    
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
    
    public func balance(of address: EthereumAddress) -> Promise<[String: Any]> {
        guard let contract = self._mpeContract,
              let balances = contract["balances"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return balances(address).call()
    }
    
    public func deposit(account: Account, amountInCogs: BigUInt) -> Promise<EthereumData> {
        guard let contract = self._mpeContract,
              let deposit = contract["deposit"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        guard let operation = deposit(amountInCogs.description).createCall() else { return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func withdraw(account: Account, amountInCogs: BigUInt) -> Promise<EthereumData> {
        guard let contract = self._mpeContract,
              let withdraw = contract["withdraw"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        guard let operation = withdraw(amountInCogs.description).createCall() else {
            return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func openChannel(account: Account, service: ServiceClient, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
        guard let contract = self._mpeContract,
              let openChannel = contract["openChannel"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }

        guard let paymentaddress = service.group["payment_address"] as? String,
              let recipientAddress = EthereumAddress(hexString: paymentaddress) else { return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            } }
        guard let groupId = service.group["group_id_in_bytes"] as? Data else { return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        let signerAddress = account.getSignerAddress()
        guard let operation = openChannel(signerAddress, recipientAddress, groupId,
                                          amountInCogs.description, expiry.description).createCall() else { return Promise { error in
                                            let genericError = NSError(
                                                      domain: "snet-sdk",
                                                      code: 0,
                                                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                                            error.reject(genericError)
                                        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func depositAndOpenChannel(account: Account, service: ServiceClient, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
        //Approve the amount
        return firstly {
            //Check account allowance
            account.allowance()
        }.then { (allowance) -> Promise<EthereumData> in
            guard let approvedAmount = allowance["alreadyApprovedAmount"] as? BigUInt else { return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            } }
            
            if amountInCogs > approvedAmount {
                guard let contract = self._mpeContract,
                      let depositAndOpenChannel = contract["depositAndOpenChannel"] else {
                    return Promise { error in
                        let genericError = NSError(
                                  domain: "snet-sdk",
                                  code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                        error.reject(genericError)
                    }
                }

                guard let paymentaddress = service.group["payment_address"] as? String,
                      let recipientAddress = EthereumAddress(hexString: paymentaddress) else { return Promise { error in
                        let genericError = NSError(
                                  domain: "snet-sdk",
                                  code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                        error.reject(genericError)
                    } }
                guard let groupId = service.group["group_id_in_bytes"] as? Data else { return Promise { error in
                    let genericError = NSError(
                              domain: "snet-sdk",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                } }
                let signerAddress = account.getSignerAddress()
                guard let operation = depositAndOpenChannel(signerAddress, recipientAddress, groupId,
                                                  amountInCogs.description, expiry.description).createCall() else { return Promise { error in
                                                    let genericError = NSError(
                                                              domain: "snet-sdk",
                                                              code: 0,
                                                              userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                                                    error.reject(genericError)
                                                } }
                return account.sendTransaction(toAddress: self.address!, operation: operation)
            } else {
                return Promise { error in
                    let genericError = NSError(
                              domain: "snet-sdk",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                }
            }
        }
    }
    
    public func channelAddFunds(account: Account, channelId: String, amountInCogs: BigUInt) -> Promise<EthereumData> {
        self._fundEscrowAccount(account: account, amountInCogs: amountInCogs)
        
        guard let contract = self._mpeContract,
              let channelAddFunds = contract["channelAddFunds"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        guard let operation = channelAddFunds(channelId, amountInCogs.description).createCall() else { return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func channelExtend(account: Account, channelId: String, expiry: BigUInt) -> Promise<EthereumData> {
        guard let contract = self._mpeContract,
              let channelExtend = contract["channelExtend"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        guard let operation = channelExtend(channelId, expiry.description).createCall() else { return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func channelExtendAndAddFunds(account: Account, channelId: String, expiry: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
        self._fundEscrowAccount(account: account, amountInCogs: amountInCogs)
        
        guard let contract = self._mpeContract,
              let channelExtendAndAddFunds = contract["channelExtendAndAddFunds"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        guard let operation = channelExtendAndAddFunds(channelId, expiry.description, amountInCogs.description).createCall() else { return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func channelClaimTimeout(account: Account, channelId: String) -> Promise<EthereumData> {
        guard let contract = self._mpeContract,
              let channelClaimTimeout = contract["channelClaimTimeout"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        guard let operation = channelClaimTimeout(channelId).createCall() else { return Promise { error in
            let genericError = NSError(
                      domain: "snet-sdk",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    public func channels(channelId: String) -> Promise<[String: Any]>{
        guard let contract = self._mpeContract,
              let channels = contract["channels"] else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return channels(channelId).call()
    }
    
    public func getPastOpenChannels(account: Account, service: ServiceClient, startingBlockNumber: BigUInt? = nil) {
        guard let fromBlock = startingBlockNumber ?? self._deploymentBlockNumber() else { return }
        let address = account.getAddress()
        guard let paymentaddress = service.group["payment_address"] as? String,
              let recipientAddress = EthereumAddress(hexString: paymentaddress) else { return }
        guard let groupId = service.group["group_id_in_bytes"] as? Data else { return }
        
        let options: [String: Any] = ["filter": [ "sender": address,
                                                  "recipient": recipientAddress,
                                                  "groupId": groupId],
                                      "fromBlock": fromBlock,
                                      "toBlock": "latest"]
        guard let filterOptions = options as? ABIEncodable else {
            return
        }
        guard let contract = self._mpeContract,
              let getPastEvents = contract["getPastEvents"] else {
            return
        }
        
        firstly {
            getPastEvents("ChannelOpen", filterOptions).call()
        }.done { channelsOpened in
            let paymentChannels = channelsOpened.map {
                if $0.key == "returnValues",
                   let returnValues = $0.value as? [String: Any],
                   let channelId = returnValues["channelId"] as? String {
                    PaymentChannel(channelId: channelId,
                                   web3: self._web3Instance,
                                   account: account,
                                   service: service,
                                   mpeContract: self)
                }
            }
        }
    }
    
    //MARK: Private methods
    
    private func _fundEscrowAccount(account: Account, amountInCogs: BigUInt) {
        let accountAddress = account.getAddress()
        firstly {
            self.balance(of: accountAddress)
        }.done { accountbalance in
            guard let currentEscrowBalance = accountbalance["currentEscrowBalance"] as? BigUInt else  { return }
            if amountInCogs > currentEscrowBalance {
                account.depositToEscrowAccount(amountInCogs: amountInCogs - currentEscrowBalance)
            }
        }
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
