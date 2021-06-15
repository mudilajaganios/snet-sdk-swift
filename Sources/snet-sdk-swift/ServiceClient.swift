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

class ServiceClient: ServiceClientProtocol, ServiceClientStateProtocol {
    
    private let _sdk: SnetSDK
    private let _mpeContract: MPEContractProtocol
    private let _options: [String: Any]
    private var _metadata: [String: Any]
    private var _group: [String: Any]
    private let _paymentChannelManagementStrategy: PaymentStrategyProtocol?
    private let _paymentChannelStateServiceClient: Escrow_PaymentChannelStateServiceClient!
    private var _paymentChannels: [PaymentChannel]
    
    private var _lastReadBlock: EthereumQuantity?
    
    init(sdk: SnetSDK, orgId: String, serviceId: String, mpeContract: MPEContractProtocol,
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
    var mpeContract: MPEContractProtocol {
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
    
    var account: AccountProtocol {
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
    
    func getChannelState(channelId: BigUInt) -> Promise<Escrow_ChannelStateReply> {
        firstly {
            self._channelStateRequest(channelId: channelId)
        }.then { stateRequest -> Promise<Escrow_ChannelStateReply> in
            do {
                let channelStateReply = try self._paymentChannelStateServiceClient.getChannelState(stateRequest).response.wait()
                return Promise<Escrow_ChannelStateReply>.value(channelStateReply)
            } catch {
                return Promise { errorreturn in
                    errorreturn.reject(error)
                }
            }
        }
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
        guard let groupIdInBytes = self._group["group_id_in_bytes"] as? [UInt8] else { return nil }
        
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
            enhancedGroup["group_id_in_bytes"] = groupID.utf8toHexBytes()
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
    
    private func _channelStateRequest(channelId: BigUInt) -> Promise<Escrow_ChannelStateRequest> {
        return firstly {
            self._channelStateRequestProperties(channelId: channelId)
        }.then { properties -> Promise<Escrow_ChannelStateRequest> in
            guard let signatureBytes = properties["signatureBytes"] as? String,
                  let currentBlock = properties["currentBlockNumber"] as? BigUInt
                  else {
                return Promise { error in
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    error.reject(genericError)
                }
            }
            
            var channelStateRequest = Escrow_ChannelStateRequest()
            channelStateRequest.channelID = Data(channelId.makeBytes())
            channelStateRequest.signature = Data(hex: signatureBytes)
            channelStateRequest.currentBlock = try! UInt64(currentBlock)
            
            return Promise<Escrow_ChannelStateRequest>.value(channelStateRequest)
        }
    }
    
    private func _channelStateRequestProperties(channelId: BigUInt) -> Promise<[String: Any]> {
        return firstly {
            self._web3.eth.blockNumber()
        }.then { blockNumber -> Promise<[String: Any]> in
            let datahex = "__get_channel_state".tohexString() +
                self._mpeContract.address!.hex(eip55: false).replacingOccurrences(of: "0x", with: "") +
                String(channelId, radix: 16).paddingLeft(toLength: 64, withPad: "0") +
                String(blockNumber.quantity, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            
            let signature = self.account.sign(dataToSign: datahex)
            var properties: [String: Any] = [:]
            properties["currentBlockNumber"] = blockNumber.quantity
            properties["signatureBytes"] = signature
            
            return Promise<[String: Any]>.value(properties)
        }
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
