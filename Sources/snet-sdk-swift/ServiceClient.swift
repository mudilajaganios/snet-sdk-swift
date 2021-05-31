//
//  ServiceClient.swift
//  
//
//  Created by Jagan Kumar Mudila on 31/03/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import PromiseKit
import GRPC
import NIO
import NIOHPACK

class ServiceClient: ServiceClientProtocol {
    
    private unowned let _sdk: SnetSDK
    private unowned let _mpeContract: MPEContract
    private let _options: [String: Any]
    private var _metadata: [String: Any]
    private var _group: [String: Any]
    private let _paymentChannelManagementStrategy: PaymentStrategyProtocol?
    private let _paymentChannelStateServiceClient: Escrow_PaymentChannelStateServiceClient!
    private var _paymentChannels: [PaymentChannel]
    
    private var _lastReadBlock: EthereumQuantity?
    
    init(sdk: SnetSDK, orgId: String, serviceId: String, mpeContract: MPEContract,
         metadata: [String: Any], group: [String: Any],
         paymentChannelManagementStrategy: PaymentStrategyProtocol? = nil,
         options: [String: Any] = [:]) {
        self._sdk = sdk
        self._metadata = metadata
        self._metadata["orgId"] = orgId
        self._metadata["serviceId"] = serviceId
        self._group = ServiceClient._enhanceGroupInfo(group: group)
        self._mpeContract = mpeContract
        self._options = options
        self._paymentChannelManagementStrategy = paymentChannelManagementStrategy
        self._paymentChannels = []
        
        var serviceEndpoint: String = ""
        if let endpoint = self._options["endpoint"] as? String {
            serviceEndpoint = endpoint
        } else if let endpoints = self._group["endpoints"] as? [String] {
            serviceEndpoint = endpoints.first ?? ""
        }
        
        let channel = GRPCUtility.getGRPCChannel(serviceEndpoint: serviceEndpoint)
        self._paymentChannelStateServiceClient = Escrow_PaymentChannelStateServiceClient(channel: channel)
    }
    
    //MARK: Publicly accessible properties
    var mpeContract: MPEContract {
        return self._mpeContract
    }
    
    var metadata: [String: Any] {
        return self._metadata
    }
    
    private var _web3: Web3 {
        self._sdk.web3Instance
    }
    
    var paymentChannelStateServiceClient: Escrow_PaymentChannelStateServiceClient? {
        return self._paymentChannelStateServiceClient
    }
    
    var paymentChannels: [PaymentChannel] {
        return _paymentChannels
    }
    
    var group: [String: Any] {
        return self._group
    }
    
    var account: Account {
        return self._sdk.account
    }
    
    var _pricePerServiceCall: BigUInt {
        guard let pricing = self.group["pricing"] as? [[String: Any]] else { return 0 }
        let fixedPricing = pricing.first { $0["price_model"] as? String == "fixed_price" }
        guard let priceinCogs = fixedPricing?["price_in_cogs"] as? UInt64 else { return 0 }
        return BigUInt(integerLiteral: priceinCogs)
    }
    
    var concurrencyFlag: Bool {
        guard let concurrency = self._options["concurrency"] as? Bool else {
            return true
        }
        
        return concurrency;
    }
    
    //MARK: methods
    
    func getChannelState(channelId: String) -> Escrow_ChannelStateReply? {
        guard let stateRequest = self._channelStateRequest(channelId: channelId) else { return nil }
        return try? self._paymentChannelStateServiceClient.getChannelState(stateRequest).response.wait()
    }
    
    func loadOpenChannels() -> Promise<[PaymentChannel]> {
        let currentBlockNumber = self.getCurrentBlockNumber()
        let newPaymentChannels = self._mpeContract.getPastOpenChannels(account: self.account,
                                                                       service: self,
                                                                       startingBlockNumber: self._lastReadBlock)
        return firstly {
            when(fulfilled: currentBlockNumber, newPaymentChannels)
        }.then { (blockNumber, newChannels) -> Promise<[PaymentChannel]> in
            self._paymentChannels += newChannels
            self._lastReadBlock = blockNumber
            
            return Promise { paymentchannels in
                paymentchannels.fulfill(self._paymentChannels)
            }
        }
    }
    
    func updateChannelStates() -> Promise<[PaymentChannel]> {
        let syncPromises = self._paymentChannels.map {
            $0.syncState()
        }
        
        return firstly {
            when(fulfilled: syncPromises)
        }.then { (_) -> Promise<[PaymentChannel]> in
            return Promise { paymentchannels in
                paymentchannels.fulfill(self._paymentChannels)
            }
        }
    }
    
    func openChannel(amount: BigUInt, expiry: BigUInt) -> Promise<PaymentChannel> {
        return firstly {
            self._mpeContract.openChannel(account: self.account, service: self, amountInCogs: amount, expiry: expiry)
        }.then { (transactionData) -> Promise<PaymentChannel> in
            return self._getNewlyOpenedChannel(from: transactionData)
        }
    }
    
    func depositAndOpenChannel(amount: BigUInt, expiry: BigUInt) -> Promise<PaymentChannel> {
        return firstly {
            self._mpeContract.depositAndOpenChannel(account: self.account, service: self, amountInCogs: amount, expiry: expiry)
        }.then { (transactionData) -> Promise<PaymentChannel> in
            return self._getNewlyOpenedChannel(from: transactionData)
        }
    }
    
    func getServiceDetails() -> [String: Any]? {
        guard let orgId = self._metadata["orgId"] as? String else { return nil }
        guard let serviceId = self._metadata["serviceId"] as? String else { return nil }
        guard let groupId = self._group["group_id"] as? String else { return nil }
        guard let groupIdInBytes = self._group["group_id_in_bytes"] as? Data else { return nil }
        
        return [
            "orgId": orgId,
            "serviceId": serviceId,
            "groupId": groupId,
            "groupIdInBytes": groupIdInBytes,
            "daemonEndpoint": self.getserviceEndPoint()
        ]
    }
    
    func getFreeCallConfiguration() -> [String: Any]? {
        guard let email = self._options["email"] as? String else { return nil }
        guard let tokenMakeFreeCall = self._options["tokenToMakeFreeCall"] as? String else { return nil }
        guard let tokenExpirationBlock = self._options["tokenExpirationBlock"] as? Int else { return nil }
        
        return [
            "email": email,
            "tokenToMakeFreeCall": tokenMakeFreeCall,
            "tokenExpiryDateBlock": tokenExpirationBlock
        ]
    }
    
    func getCurrentBlockNumber() -> Promise<EthereumQuantity> {
        return self._web3.eth.blockNumber()
    }
    
    func sign(dataToSign: String) -> String {
        return self.account.sign(dataToSign: dataToSign)
    }
    
    /// Default Channel Expiration
    /// - Returns: Expiration
    func defaultChannelExpiration() -> Promise<BigUInt> {
        return firstly {
            self.getCurrentBlockNumber()
        }.then { currentBlockNumber -> Promise<BigUInt> in
            var defaultExpiration: BigUInt = currentBlockNumber.quantity
            defaultExpiration += self._getPaymentExpiryThreshold()
            return Promise { expiration in
                expiration.fulfill(defaultExpiration)
            }
        }
    }
    
    //MARK: Private methods
    private func _getPaymentExpiryThreshold() -> BigUInt {
        guard let payment = self._group["payment"] as? [String: Any],
              let paymentThresholdInt = payment["payment_expiration_threshold"] as? UInt64 else {
            return 0
        }
        let paymentThreshold = BigUInt(integerLiteral: paymentThresholdInt)
        return paymentThreshold
    }
    
    private static func _enhanceGroupInfo(group: [String: Any]) -> [String: Any] {
        var enhancedGroup = group
        if let groupID = group["group_id"] as? String {
            enhancedGroup["group_id_in_bytes"] = groupID.utf8toBase64()
        }
        if let payment = group["payment"] as? [String: Any] {
            enhancedGroup["payment_address"] = payment["payment_address"]
            enhancedGroup["payment_expiration_threshold"] = payment["payment_expiration_threshold"]
        }
        return enhancedGroup
    }
    
    private func _getNewlyOpenedChannel(from transaction: EthereumData) -> Promise<PaymentChannel> {
        return firstly {
            self._web3.eth.getTransactionReceipt(transactionHash: transaction)
        }.then { (transactionReceipt) -> Promise<PaymentChannel> in
            guard let reciept = transactionReceipt else {
                return Promise { error in
                    let genericError = NSError(
                              domain: "snet-sdk",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                }
            }
            return self._getNewlyOpenedChannel(receipent: reciept)
        }
    }
    
    private func _getNewlyOpenedChannel(receipent: EthereumTransactionReceiptObject) -> Promise<PaymentChannel> {
        return firstly {
            self._mpeContract.getPastOpenChannels(account: self.account, service: self, startingBlockNumber: receipent.blockNumber)
        }.then { (openChannels) -> Promise<PaymentChannel> in
            return Promise { result in
                guard let newlyOpenedChannel = openChannels.first else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    result.reject(genericError)
                    return
                }
                result.fulfill(newlyOpenedChannel)
            }
        }
    }
    
    private func _channelStateRequest(channelId: String) -> Escrow_ChannelStateRequest? {
        let properties = self._channelStateRequestProperties(channelId: channelId)
        
        guard let signatureBytes = properties["signatureBytes"] as? Data,
              let currentBlock = try? UInt64((properties["currentBlockNumber"] as? BigUInt)!)
              else {
            return nil
        }
        
        var channelStateRequest = Escrow_ChannelStateRequest()
        channelStateRequest.channelID = channelId.data(using: .utf8)!
        channelStateRequest.signature = signatureBytes
        channelStateRequest.currentBlock = currentBlock
        
        return channelStateRequest
    }
    
    private func _channelStateRequestProperties(channelId: String) -> [String: Any] {
        var properties: [String: Any] = [:]
        firstly {
            self._web3.eth.blockNumber()
        }.done { blockNumber in
            let datahex = "__get_channel_state".tohexString() +
                self._mpeContract.address!.hex(eip55: true) +
                channelId.tohexString() +
                blockNumber.hex()
            
            var signature = self.account.sign(dataToSign: datahex)
            let hexBytes = signature.hexToBytes()
            signature = Data(hexBytes).base64EncodedString(options: .init(rawValue: 0))
            properties["currentBlockNumber"] = blockNumber
            properties["signatureBytes"] = signature
        }
        
        return properties
    }
    
    private func _fetchPaymentMetadata() -> Promise<[[String: Any]]> {
        return self._paymentChannelManagementStrategy!.getPaymentMetadata(serviceClient: self)
    }
    
    func getserviceEndPoint() -> String {
        if let endpoint = self._options["endpoint"] as? String {
            return endpoint
        } else {
            guard let endpoints = self._group["endpoints"] as? [String],
                  let endpoint = endpoints.first else {
                return ""
            }
            return endpoint
        }
    }
    
    public var serviceChannel: GRPCChannel {
        let serviceEndpoint = self.getserviceEndPoint()
        let channel = GRPCUtility.getGRPCChannel(serviceEndpoint: serviceEndpoint)
        return channel
    }
    
    public func getServiceClientOptions() -> Promise<CallOptions?> {
        guard let disableBlockchainOperations = self._options["disableBlockchainOperations"] as? Bool,
              !disableBlockchainOperations else {
            return Promise { options in
                options.fulfill(nil)
            }
        }
        
        return firstly {
            self._fetchPaymentMetadata()
        }.then { (metadata) -> Promise<CallOptions?> in
            let headers = metadata.map { ($0.first?.key ?? "", ($0.first?.value as? String) ?? "") }
            let hpackHeaders = HPACKHeaders(headers)
            return Promise { options in
                options.fulfill(CallOptions(customMetadata: hpackHeaders))
            }
        }
    }
}
