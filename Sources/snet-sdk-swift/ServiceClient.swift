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

class ServiceClient {
    
    private unowned let _sdk: SnetSDK
    private unowned let _mpeContract: MPEContract
    private let _options: [String: Any]
    private var _metadata: [String: Any]
    private var _group: [String: Any]
    private let _paymentChannelManagementStrategy: Any?
    private let _paymentChannelStateServiceClient: Escrow_PaymentChannelStateServiceClient!
    private var _paymentChannels: [PaymentChannel]
    
    private var _lastReadBlock: EthereumQuantity?
    
    init(sdk: SnetSDK, orgId: String, serviceId: String, mpeContract: MPEContract,
         metadata: [String: Any], group: [String: Any],
         paymentChannelManagementStrategy: Any? = nil,
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
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
          try? group.syncShutdownGracefully()
        }
        
        var channel: GRPCChannel?
        
        if serviceEndpoint.starts(with: "https") {
            channel = ClientConnection.secure(group: group).connect(host: serviceEndpoint, port: 443)
        } else if serviceEndpoint.starts(with: "http") {
            channel = ClientConnection.insecure(group: group).connect(host: serviceEndpoint, port: 80)
        }
        
        guard let channel = channel else { preconditionFailure("Channel initialization is failed")}
//        return
        
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
        guard let priceinCogs = fixedPricing?["price_in_cogs"] as? Int else { return 0 }
        return BigUInt(priceinCogs)
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
    
    func loadOpenChannels() -> [PaymentChannel] {
        firstly {
            self.getCurrentBlockNumber()
        }.done { currentBlockNumber in
            let newPaymentChannels = self._mpeContract.getPastOpenChannels(account: self.account,
                                                                           service: self,
                                                                           startingBlockNumber: self._lastReadBlock)
            
            self._paymentChannels += newPaymentChannels
            self._lastReadBlock = currentBlockNumber
        }
        return self._paymentChannels
    }
    
    func updateChannelStates() -> [PaymentChannel] {
        let syncPromises = self._paymentChannels.map {
            $0.syncState()
        }
        
        firstly {
            when(fulfilled: syncPromises)
        }.done { _ in
            
        }
        
        return self._paymentChannels
    }
    
    func openChannel(amount: BigUInt, expiry: BigUInt) {
        let newChannelReceipt = self._mpeContract.openChannel(account: self.account, service: self, amountInCogs: amount, expiry: expiry)
    }
    
    func depositAndOpenChannel(amount: BigUInt, expiry: BigUInt) {
        firstly {
            self._mpeContract.depositAndOpenChannel(account: self.account, service: self, amountInCogs: amount, expiry: expiry)
        }.done { (transactionData) in
            self._web3.eth.getTransactionReceipt(transactionHash: transactionData)
//            self._getNewlyOpenedChannel()
        }
    }
    
    func getServiceDetails() -> [String: Any]? {
        guard let orgId = self._metadata["orgId"] as? String else { return nil }
        guard let serviceId = self._metadata["serviceId"] as? String else { return nil }
        guard let groupId = self._group["group_id"] as? String else { return nil }
        guard let groupIdInBytes = self._group["group_id_in_bytes"] as? String else { return nil }
        
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
        guard let tokenExpirationBlock = self._options["tokenExpirationBlock"] as? String else { return nil }
        
        return [
            "email": email,
            "tokenToMakeFreeCall": tokenMakeFreeCall,
            "tokenExpiryDateBlock": tokenExpirationBlock
        ]
    }
    
    func getCurrentBlockNumber() -> Promise<EthereumQuantity> {
        return self._web3.eth.blockNumber()
    }
    
    func sign(_ dataToSign: [DataToSign]) -> String {
        return self.account.sign(dataToSign)
    }
    
    
    /// Default Channel Expiration
    /// - Returns: Expiration
    func defaultChannelExpiration() -> BigUInt {
        var defaultExpiration: BigUInt = 0
        firstly {
            self.getCurrentBlockNumber()
        }.done { currentBlockNumber in
            defaultExpiration = currentBlockNumber.quantity
            defaultExpiration += self._getPaymentExpiryThreshold()
        }
        
        return defaultExpiration
    }
    
    //MARK: Private methods
    private func _getPaymentExpiryThreshold() -> BigUInt {
        guard let payment = self._group["payment"] as? [String: Any],
              let paymentThresholdString = payment["payment_expiration_threshold"] as? String,
              let paymentThreshold = BigUInt(paymentThresholdString) else {
            return 0
        }
        return paymentThreshold
    }
    
    private static func _enhanceGroupInfo(group: [String: Any]) -> [String: Any] {
        var enhancedGroup = group
        if let groupID = group["group_id"] as? String,
           let groupIDBytes = groupID.data(using: .ascii) {
            enhancedGroup["group_id_in_bytes"] = groupIDBytes
        }
        if let payment = group["payment"] as? [String: Any] {
            enhancedGroup["payment_address"] = payment["payment_address"]
            enhancedGroup["payment_expiration_threshold"] = payment["payment_expiration_threshold"]
        }
        return enhancedGroup
    }
    
    private func _getNewlyOpenedChannel(receipent: EthereumTransactionReceiptObject) -> PaymentChannel? {
        let openChannels = self._mpeContract.getPastOpenChannels(account: self.account, service: self, startingBlockNumber: receipent.blockNumber)
        return openChannels.first
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
            let signature = self.account.sign([DataToSign(t: "string", v: "__get_channel_state"),
                               DataToSign(t: "address", v: self._mpeContract.address),
                               DataToSign(t: "uint256", v: channelId),
                               DataToSign(t: "uint256", v: blockNumber.quantity)])
            properties["currentBlockNumber"] = blockNumber
            properties["signatureBytes"] = signature.bytes
        }
        
        return properties
    }
    
    //TODO: Need to confirm the type of Payment Strategy
    private func _fetchPaymentMetadata() {
        
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
    
    //TODO: Need to work on the GRPC implementation
    fileprivate func _generatePaymentChannelStateServiceClient() -> Escrow_PaymentChannelStateServiceClient {
        let serviceEndpoint = self.getserviceEndPoint()
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
          try? group.syncShutdownGracefully()
        }
        
        var channel: GRPCChannel?
        
        if serviceEndpoint.starts(with: "https") {
            channel = ClientConnection.secure(group: group).connect(host: serviceEndpoint, port: 443)
        } else if serviceEndpoint.starts(with: "http") {
            channel = ClientConnection.insecure(group: group).connect(host: serviceEndpoint, port: 80)
        }
        
        guard let channel = channel else { preconditionFailure("Channel initialization is failed")}
        return Escrow_PaymentChannelStateServiceClient(channel: channel)
    }
    
    //TODO: Need to work on the GRPC implementation
    private func _getChannelStateRequestMethodDescriptor() {
        
    }
    
    //TODO: Need to confirm the GRPC implementation
    private func _getGrpcChannelCredentials(serviceEndpoint: String) {
        guard let endpointURL = URL(string: serviceEndpoint) else { return }
        
//        endpointURL.
    }
}
