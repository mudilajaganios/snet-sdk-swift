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

class MPEContract: MPEContractProtocol {
    
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
    
    var contract: DynamicContract {
        return self._mpeContract!
    }
    
    ///address of the MPE contract
    var address: EthereumAddress? {
        return self._mpeContract?.address
    }
    
    func balance(of address: EthereumAddress) -> Promise<[String: Any]> {
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
    
    func deposit(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData> {
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
        let operation = deposit(amountInCogs.description)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func withdraw(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData> {
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
        let operation = withdraw(amountInCogs.description)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func openChannel(account: AccountProtocol, service: ServiceClientStateProtocol, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
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
        guard let groupId = service.group["group_id_in_bytes"] as? [UInt8] else { return Promise { error in
            let genericError = NSError(
                domain: "snet-sdk",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            error.reject(genericError)
        } }
        let signerAddress = account.getSignerAddress()
        let operation = openChannel(signerAddress, recipientAddress, groupId, amountInCogs, expiry)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func depositAndOpenChannel(account: AccountProtocol, service: ServiceClientStateProtocol, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
        //Approve the amount
        return firstly {
            //Check account allowance
            account.allowance()
        }.then { (allowance) -> Promise<Void> in
            let approvedAmount = (allowance.values.first as? BigUInt) ?? BigUInt(0)
            
            if BigUInt.compare(amountInCogs, approvedAmount) == .orderedDescending {
                return account.approveTransfer(amountInCogs: amountInCogs).asVoid()
            } else {
                return Promise.value
            }
        }.then { _ -> Promise<EthereumData> in
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
            guard let groupId = service.group["group_id_in_bytes"] as? [UInt8] else { return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            } }
            let signerAddress = account.getSignerAddress()
            let operation = depositAndOpenChannel(signerAddress, recipientAddress, groupId, amountInCogs, expiry)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelAddFunds(account: AccountProtocol, channelId: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
        return firstly {
            self._fundEscrowAccount(account: account, amountInCogs: amountInCogs)
        }.then { _ -> Promise<EthereumData> in
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
            let operation = channelAddFunds(channelId, amountInCogs.description)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelExtend(account: AccountProtocol, channelId: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
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
        let operation = channelExtend(channelId, expiry.description)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func channelExtendAndAddFunds(account: AccountProtocol, channelId: BigUInt, expiry: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
        return firstly {
            self._fundEscrowAccount(account: account, amountInCogs: amountInCogs)
        }.then { _ -> Promise<EthereumData> in
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
            let operation = channelExtendAndAddFunds(channelId, expiry.description, amountInCogs.description)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelClaimTimeout(account: AccountProtocol, channelId: BigUInt) -> Promise<EthereumData> {
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
        let operation = channelClaimTimeout(channelId)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func channels(channelId: BigUInt) -> Promise<[String: Any]> {
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
    
    func getPastOpenChannels(account: AccountProtocol, service: ServiceClientStateProtocol, startingBlockNumber: EthereumQuantity? = nil) -> Promise<[PaymentChannel]> {
        let address = account.getAddress()

        guard let groupId = service.group["group_id"] as? String else {
            return Promise<[PaymentChannel]>.value([])
        }
        
        guard let contract = self._mpeContract  else  {
            return Promise<[PaymentChannel]>.value([])
        }
        
        return firstly {
            self._deploymentBlockNumber(startingBlockNumber: startingBlockNumber)
        }.then{ fromBlock -> Promise<[String: Any]> in
           return contract["nextChannelId"]!().call()
        }.then({ (nextChannelID) -> Promise<BigInt> in
            guard let nextChannelId = nextChannelID.values.first as? BigUInt, nextChannelId > 0 else { return Promise<BigInt>.value(-1) }
            return self._getOpenChannelId(channelId: BigInt(nextChannelId) - 1, groupId: groupId, address: address)
        }).then { (openChannelId) -> Promise<[PaymentChannel]> in
            if openChannelId < 0 {
                return Promise<[PaymentChannel]>.value([])
            }
            return Promise { paymentchannels in
                let channels: [PaymentChannel] =  [PaymentChannel(channelId: BigUInt(openChannelId),
                                          web3: self._web3Instance,
                                          account: account,
                                          service: service,
                                          mpeContract: self)]
                return paymentchannels.fulfill(channels)
            }
        }
    }
    
    //MARK: Private methods
    
    private func _getOpenChannelId(channelId: BigInt, groupId: String, address: EthereumAddress) -> Promise<BigInt> {
        if channelId < 0 {
            return Promise<BigInt>.value(channelId)
        }
        return firstly {
            self.channels(channelId: BigUInt(channelId))
        }.then { channelInfo -> Promise<BigInt> in
            guard let groupIdData = channelInfo["groupId"] as? Data,
                  let senderAddress = channelInfo["sender"] as? EthereumAddress,
                  let signerAddress = channelInfo["signer"] as? EthereumAddress,
                  let recipientAddress = channelInfo["recipient"] as? EthereumAddress else {
                return Promise { error in
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Could not retrieve channel information"])
                    error.reject(genericError)
                }
            }
            
            let groupIdString = groupIdData.base64EncodedString()
            if (address == senderAddress || address == signerAddress || address == recipientAddress) && groupIdString == groupId {
                return Promise<BigInt>.value(channelId)
            }
            
            return self._getOpenChannelId(channelId: channelId - 1, groupId: groupId, address: address)
        }
    }
    
    private func _fundEscrowAccount(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData> {
        let accountAddress = account.getAddress()
        return firstly {
            self.balance(of: accountAddress)
        }.then { accountbalance -> Promise<EthereumData> in
            guard let currentEscrowBalance = accountbalance.values.first as? BigUInt else  {
                return Promise { error in
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Could not get the current Escrow Balance"])
                    error.reject(genericError)
                } }
            if BigUInt.compare(amountInCogs, currentEscrowBalance) == .orderedDescending {
                return account.depositToEscrowAccount(amountInCogs: amountInCogs - currentEscrowBalance)
            }
            return Promise<EthereumData>.value(EthereumData([]))
        }
    }
    
    private func _deploymentBlockNumber(startingBlockNumber: EthereumQuantity? = nil) -> Promise<EthereumQuantity> {
        if let startingblock = startingBlockNumber {
            return Promise<EthereumQuantity>.value(startingblock)
        }
        let networks = SNETContracts.shared.getNetworks(networkId: self._networkId, contractType: .mpe)
        guard let transactionHash = networks["transactionHash"] as? String else {
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return firstly {
            self._web3Instance.eth.getTransactionReceipt(transactionHash: EthereumData(transactionHash.hexToBytes()))
        }.then { receiptObject -> Promise<EthereumQuantity> in
            guard let receipt = receiptObject else { return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            } }
            return Promise<EthereumQuantity>.value(receipt.blockNumber)
        }
    }
}

typealias Web3ResponseCompletion<Result: Codable> = (_ resp: Web3Response<Result>) -> Void

struct inputParams: Codable {
    let filter: [String: String]
    let fromBlock: String
    let toBlock: String
}
