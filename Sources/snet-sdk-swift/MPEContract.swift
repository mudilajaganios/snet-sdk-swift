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

class MPEContract {
    
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
    
    func deposit(account: Account, amountInCogs: BigUInt) -> Promise<EthereumData> {
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
    
    func withdraw(account: Account, amountInCogs: BigUInt) -> Promise<EthereumData> {
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
    
    func openChannel(account: Account, service: ServiceClient, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
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
    
    func depositAndOpenChannel(account: Account, service: ServiceClient, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
        //Approve the amount
        return firstly {
            //Check account allowance
            account.allowance()
        }.then { (allowance) -> Promise<Void> in
            guard let approvedAmount = allowance.first?.value as? BigUInt else { return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to fetch approved amount"])
                error.reject(genericError)
            } }
            
            if amountInCogs > approvedAmount {
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
            let operation = depositAndOpenChannel(signerAddress, recipientAddress, groupId,
                                                        amountInCogs, expiry)
            return account.sendTransaction(toAddress: self.address!, operation: operation)
        }
    }
    
    func channelAddFunds(account: Account, channelId: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
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
        let operation = channelAddFunds(channelId, amountInCogs.description)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func channelExtend(account: Account, channelId: BigUInt, expiry: BigUInt) -> Promise<EthereumData> {
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
    
    func channelExtendAndAddFunds(account: Account, channelId: BigUInt, expiry: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData> {
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
        let operation = channelExtendAndAddFunds(channelId, expiry.description, amountInCogs.description)
        return account.sendTransaction(toAddress: self.address!, operation: operation)
    }
    
    func channelClaimTimeout(account: Account, channelId: BigUInt) -> Promise<EthereumData> {
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
    
    func channels(channelId: BigUInt) -> Promise<[String: Any]>{
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
    
    func getPastOpenChannels(account: Account, service: ServiceClient, startingBlockNumber: EthereumQuantity? = nil) -> Promise<[PaymentChannel]> {
        let address = account.getAddress()
        guard let paymentaddress = service.group["payment_address"] as? String,
              let recipientAddress = EthereumAddress(hexString: paymentaddress) else {
            return Promise<[PaymentChannel]>.value([])
        }
        guard let groupId = service.group["group_id_in_bytes"] as? [UInt8] else {
            return Promise<[PaymentChannel]>.value([])
        }
        
        guard let contract = self._mpeContract  else  {
            return Promise<[PaymentChannel]>.value([])
        }
        
//        let channelOpenEvent = contract.events.first(where: { $0.name == "ChannelOpen" })
        
        return firstly {
            self._deploymentBlockNumber(startingBlockNumber: startingBlockNumber)
        }.then{ fromBlock -> Promise<[String: Any]> in
           return contract["nextChannelId"]!().call()
            
//            let options = inputParams(filter: ["sender": address.hex(eip55: false),
//                                               "recipient": recipientAddress.hex(eip55: false),
//                                               "groupId": groupId.description], fromBlock: fromBlock.hex(), toBlock: "latest")
//
//                let req = RPCRequest<inputParams>(
//                    id: self._web3Instance.properties.rpcId,
//                    jsonrpc: Web3.jsonrpc,
//                    method: "eth_getLogs",
//                    params: options
//                )
//
//            self.getEvents(req: req) { response in
//                print(response)
//            }
            
//            guard let filterOptions = options as? ABIEncodable else  {
//                return Promise { error in
//                    let genericError = NSError(
//                        domain: "snet-sdk",
//                        code: 0,
//                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
//                    error.reject(genericError)
//                }
//            }
            
//            return SolidityEmittedEvent(name: "ChannelOpen", values: [:]).promise
            
//            return channelOpenEvent . . getPastEvents("ChannelOpen", filterOptions).call()
        }.then { (nextChannelID) -> Promise<[PaymentChannel]> in
            guard let nextChannelId = nextChannelID.values.first as? BigUInt, nextChannelId > 1 else { return Promise<[PaymentChannel]>.value([]) }
            
            return Promise { paymentchannels in
//                let channels: [PaymentChannel] = channelsOpened.filter({ $0.key == "returnValues" }).map {
//                    let returnValues = $0.value as? [String: Any]
//                    let channelId = returnValues?["channelId"] as? String
//TODO: Make Sure a currect implementation for the channel
                let channels: [PaymentChannel] =  [PaymentChannel(channelId: 2,//nextChannelId - 1,
                                          web3: self._web3Instance,
                                          account: account,
                                          service: service,
                                          mpeContract: self)]
//                }

                return paymentchannels.fulfill(channels)
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
    
    func getEvents(
        req: RPCRequest<inputParams>,
        response: @escaping Web3ResponseCompletion<EthereumData>
    ) {
        self._web3Instance.properties.provider.send(request: req, response: response)
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
