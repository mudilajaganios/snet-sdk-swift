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
import CryptoSwift

class MPEContract: MPEContractProtocol {
    
    private let _web3Instance: Web3
    private let _networkId: String
    private var _mpeContract: DynamicContract
    private var _ethereumAddress: EthereumAddress?
    
    init(web3: Web3, networkId: String) throws {
        self._web3Instance = web3
        self._networkId = networkId
        
        let networkAddress = SNETContracts.shared.getNetworkAddress(networkId: networkId, contractType: .mpe)
        
        self._ethereumAddress = EthereumAddress(hexString: networkAddress)
        do {
            guard let mpeContractData = SNETContracts.shared.abiContract(contractType: .mpe) else {
                throw SnetError.dataNotAvailable("Unable to parse MPE Contract")
            }
            self._mpeContract = try self._web3Instance.eth.Contract(json: mpeContractData,
                                                                     abiKey: nil,
                                                                     address: self._ethereumAddress)
        } catch {
            throw SnetError.failedContractInit("MPE Contract")
        }
        
    }
    
    var contract: DynamicContract {
        return self._mpeContract
    }
    
    ///address of the MPE contract
    var address: EthereumAddress? {
        return self._mpeContract.address
    }
    
    func balance(of address: EthereumAddress) -> Promise<[String: Any]> {
        guard let balances = self._mpeContract["balances"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("Balances method is not available in MPE Contract"))
            }
        }
        return balances(address).call()
    }
    
    func deposit(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData> {
        guard let deposit = self._mpeContract["deposit"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("deposit method is not available in MPE Contract"))
            }
        }
        let operation = deposit(amountInCogs)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func withdraw(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData> {
        guard let withdraw = self._mpeContract["withdraw"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("withdraw method is not available in MPE Contract"))
            }
        }
        let operation = withdraw(amountInCogs)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func openChannel(account: AccountProtocol, service: ServiceClientStateProtocol, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
        guard let openChannel = self._mpeContract["openChannel"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("openChannel method is not available in MPE Contract"))
            }
        }
        
        guard let paymentaddress = service.group["payment_address"] as? String,
              let recipientAddress = EthereumAddress(hexString: paymentaddress),
              let groupId = service.group["group_id_in_bytes"] as? [UInt8] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("Group Information is not available for the service"))
            }
        }
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
            guard let depositAndOpenChannel = self._mpeContract["depositAndOpenChannel"] else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("depositAndOpenChannel method is not available in MPE Contract"))
                }
            }
            
            guard let paymentaddress = service.group["payment_address"] as? String,
                  let recipientAddress = EthereumAddress(hexString: paymentaddress),
                  let groupId = service.group["group_id_in_bytes"] as? [UInt8] else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Group Information is not available for the service"))
                }
            }
            let signerAddress = account.getSignerAddress()
            let operation = depositAndOpenChannel(signerAddress, recipientAddress, groupId, amountInCogs, expiry)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelAddFunds(account: AccountProtocol, channelId: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
        return firstly {
            self._fundEscrowAccount(account: account, amountInCogs: amountInCogs)
        }.then { _ -> Promise<EthereumData> in
            guard let channelAddFunds = self._mpeContract["channelAddFunds"] else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("channelAddFunds method is not available in MPE Contract"))
                }
            }
            let operation = channelAddFunds(channelId, amountInCogs)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelExtend(account: AccountProtocol, channelId: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
        guard let channelExtend = self._mpeContract["channelExtend"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("channelExtend method is not available in MPE Contract"))
            }
        }
        let operation = channelExtend(channelId, expiry)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func channelExtendAndAddFunds(account: AccountProtocol, channelId: BigUInt, expiry: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
        return firstly {
            self._fundEscrowAccount(account: account, amountInCogs: amountInCogs)
        }.then { _ -> Promise<EthereumData> in
            guard let channelExtendAndAddFunds = self._mpeContract["channelExtendAndAddFunds"] else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("channelExtendAndAddFunds method is not available in MPE Contract"))
                }
            }
            let operation = channelExtendAndAddFunds(channelId, expiry, amountInCogs)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelClaimTimeout(account: AccountProtocol, channelId: BigUInt) -> Promise<EthereumData> {
        guard let channelClaimTimeout = self._mpeContract["channelClaimTimeout"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("channelClaimTimeout method is not available in MPE Contract"))
            }
        }
        let operation = channelClaimTimeout(channelId)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func channels(channelId: BigUInt) -> Promise<[String: Any]> {
        guard let channels = self._mpeContract["channels"] else {
            return Promise { error in
                error.reject(SnetError.dataNotAvailable("channels method is not available in MPE Contract"))
            }
        }
        return channels(channelId).call()
    }
    
    func getPastOpenChannels(account: AccountProtocol, service: ServiceClientStateProtocol, startingBlockNumber: EthereumQuantity? = nil) -> Promise<[PaymentChannel]> {
        return firstly {
            self._deploymentBlockNumber(startingBlockNumber: startingBlockNumber)
        }.then({ fromBlock -> Promise<BigUInt> in
            guard let pastEvent = self._mpeContract.events.first(where: { $0.name == "ChannelOpen" }) else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("ChannelOpen event is not emitted in MPE Contract"))
                }
            }
            
            let signature = "0x" + SHA3(variant: .keccak256).calculate(for: pastEvent.signature.bytes).toHexString()
            let fromBlock = fromBlock.hex()
            let toBlock = "latest"
            
            guard let address = self._mpeContract.address?.hex(eip55: false),
                let sender = account.getAddress().abiEncode(dynamic: false),
                let paymentaddress = service.group["payment_address"] as? String,
                let recipientAddress = EthereumAddress(hexString: paymentaddress)?.abiEncode(dynamic: false),
                  let groupId = service.group["group_id_in_bytes"] as? [UInt8] else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Group Information is not available for the service"))
                }
            }
            
            let pastEventParams = ChannelOpenEventParams(address: address,
                                                         fromBlock: fromBlock,
                                                         toBlock: toBlock,
                                                         topics: [signature,
                                                                  "0x" + sender,
                                                                  "0x" + recipientAddress,
                                                                  "0x" + groupId.toHexString()])
            
            return self._web3Instance.eth.getPastEvents(params: pastEventParams)
                .then { pastEvents -> Promise<BigUInt> in
                    guard let eventData = try? ABI.decodeLog(event: pastEvent, from: pastEvents[0]),
                          let channelId = eventData["channelId"] as? BigUInt else {
                        return Promise { error in
                            error.reject(SnetError.dataNotAvailable("Missing ChannelId Information"))
                        }
                    }
                    return Promise<BigUInt>.value(channelId)
                }
        }).then { (openChannelId) -> Promise<[PaymentChannel]> in
            if openChannelId < 0 {
                return Promise<[PaymentChannel]>.value([])
            }
            return Promise { paymentchannels in
                let channels: [PaymentChannel] =  [PaymentChannel(channelId: openChannelId,
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
                    error.reject(SnetError.dataNotAvailable("Could not retrieve channel information"))
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
                    error.reject(SnetError.dataNotAvailable("Could not get the current Escrow Balance"))
                }
            }
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
                error.reject(SnetError.dataNotAvailable("transactionHash is not found in Network details"))
            }
        }
        return firstly {
            self._web3Instance.eth.getTransactionReceipt(transactionHash: EthereumData(transactionHash.hexToBytes()))
        }.then { receiptObject -> Promise<EthereumQuantity> in
            guard let receipt = receiptObject else { return Promise { error in
                error.reject(SnetError.dataNotAvailable("Could not retrieve transaction receipt"))
            } }
            return Promise<EthereumQuantity>.value(receipt.blockNumber)
        }
    }
}
