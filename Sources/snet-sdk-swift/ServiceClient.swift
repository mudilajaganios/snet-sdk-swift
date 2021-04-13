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

public final class ServiceClient {
    
    private let _sdk: SnetSDK
    private let _mpeContract: MPEContract
    private let _options: [String: Any]
    private var _metadata: [String: Any]
    private var _group: [String: Any]
    private let _paymentChannelManagementStrategy: [String: Any]
    private let _paymentChannelStateServiceClient: [String: Any]
    private var _paymentChannels: [String]
    
    init(sdk: SnetSDK, orgId: String, serviceId: String, mpeContract: MPEContract,
         metadata: [String: Any], group: [String: Any],
         paymentChannelManagementStrategy: [String: Any],
         options: [String: Any] = [:]) {
        self._sdk = sdk
        self._metadata = metadata
        self._metadata["orgId"] = orgId
        self._metadata["serviceId"] = serviceId
        self._group = ServiceClient._enhanceGroupInfo(group: group)
        self._mpeContract = mpeContract
        self._options = options
        self._paymentChannelManagementStrategy = paymentChannelManagementStrategy
        self._paymentChannelStateServiceClient = [:]
        self._paymentChannels = []
    }
    
    //MARK: Publicly accessible properties
    public var mpeContract: MPEContract {
        return self._mpeContract
    }
    
    public var metadata: [String: Any] {
        return self._metadata
    }
    
    private var _web3: Web3 {
        self._sdk.web3Instance
    }
    
    public var paymentChannelStateServiceClient: [String: Any] {
        return self._paymentChannelStateServiceClient
    }
    
    public var paymentChannels: [String] {
        return _paymentChannels
    }
    
    //MARK: Public methods
    
    public func getChannelState() {
        
    }
    
    public func loadOpenChannels() {
        firstly {
            self.getCurrentBlockNumber()
        }.done { currentBlockNumber in
//            self._mpeContract.getPastOpenChannels()
//            defaultExpiration = currentBlockNumber.quantity
//            defaultExpiration += self._getPaymentExpiryThreshold()
        }
    }
    
    public func updateChannelStates() {
        
    }
    
    public func openChannel(amount: Double, expiry: Double) {
        
    }
    
    public func depositAndOpenChannel(amount: Double, expiry: Double) {
        
    }
    
    public func getServiceDetails() -> [String: Any] {
        return [
            "orgId": "this._metadata.orgId",
            "serviceId": "this._metadata.serviceId",
            "groupId": "this._group.group_id",
            "groupIdInBytes": "this._group.group_id_in_bytes",
            "daemonEndpoint": "this._getServiceEndpoint()"
        ]
    }
    
    public func getFreeCallConfiguration() -> [String: Any] {
        return [
          "email": "",
          "tokenToMakeFreeCall": "",
          "tokenExpiryDateBlock": ""
        ]
    }
    
    public func getCurrentBlockNumber() -> Promise<EthereumQuantity> {
        return self._web3.eth.blockNumber()
    }
    
    public func signData() {
        
    }
    
    
    /// Default Channel Expiration
    /// - Returns: Expiration
    public func defaultChannelExpiration() -> BigUInt {
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
    
    private func _channelStateRequest() {
        
    }
    
    private func _channelStateRequestProperties() {
        
    }
    
    private func _fetchPaymentMetadata() {
        
    }
    
    private func _getserviceEndPoint() {
        
    }
    
    private func _generatePaymentChannelStateServiceClient() {
        
    }
    
    private func _getChannelStateRequestMethodDescriptor() {
        
    }
}
