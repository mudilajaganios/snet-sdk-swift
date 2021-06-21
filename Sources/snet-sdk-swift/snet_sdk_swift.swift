//
//  SnetSDK.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 17/03/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit

public class SnetSDK {
    
    private let _web3: Web3
    private let _metadataProvider: IPFSMetadataProvider
    private let _mpeContract: MPEContractProtocol
    private let _account: AccountProtocol
    
    private var _paymentChannelManagementStrategy: PaymentStrategyProtocol?
    
    public init(config: SDKConfig) throws {
        let rpcId = Int(config.networkId) ?? 1
        let web3 = Web3(rpcURL: config.web3Provider, rpcId: rpcId)
        self._web3 = web3
        let identity = PrivateKeyIdentity(config: config, web3: web3)
        
        do {
            let mpeContract = try MPEContract(web3: web3, networkId: config.networkId)
            self._mpeContract = mpeContract
            self._account = Account(web3: web3, networkId: config.networkId, mpeContract: mpeContract, identity: identity)
            self._metadataProvider = try IPFSMetadataProvider(web3: web3, networkId: config.networkId,
                                                                             ipfsEndpoint: config.ipfsEndpoint)
        } catch {
            throw error
        }
    }
    
    public var web3Instance: Web3 {
        return self._web3
    }
    
    var account: AccountProtocol {
        return self._account
    }
    
    public var paymentChannelManagementStrategy: PaymentStrategyProtocol? {
        get {
            return self._paymentChannelManagementStrategy
        }
        set {
            self._paymentChannelManagementStrategy = newValue
        }
    }
    
    public func createServiceClient(orgId: String,
                             serviceId: String,
                             groupName: String = "default_group",
                             paymentChannelManagementStrategy: PaymentStrategyProtocol? = nil,
                             options: [String: Any] = [:],
                             concurrentCalls: Int = 1) -> Promise<ServiceClientProtocol> {
        firstly {
            self._metadataProvider.metadata(orgId: orgId, serviceId: serviceId)
        }.then { (metadata) -> Promise<ServiceClientProtocol> in
            return Promise { serviceClientPromise in
                guard let group = self._serviceGroup(serviceMetadata: metadata, groupName: groupName) else {
                    print("Error: Group is not found in the Service metadata")
                    serviceClientPromise.reject(SnetError.dataNotAvailable("Group is not found in the Service metadata"))
                    return
                }
                let paymentStrategy = self._constructStrategy(paymentChannelStrategy: paymentChannelManagementStrategy, concurrentCalls: concurrentCalls)
                let serviceClient = ServiceClient(sdk: self, orgId: orgId, serviceId: serviceId,
                                                  mpeContract: self._mpeContract,
                                                  metadata: metadata,
                                                  group: group,
                                                  paymentChannelManagementStrategy: paymentStrategy,
                                                  options: options)
                print("Info: Service client is created successfully")
                serviceClientPromise.fulfill(serviceClient)
            }
        }
    }
    
    fileprivate func _serviceGroup(serviceMetadata: [String: Any], groupName: String) -> [String: Any]? {
        guard let groups = serviceMetadata["groups"] as? [[String: Any]],
              let group = groups.first(where: { $0["group_name"] as! String == groupName })
              else {
            return nil
        }
        return group
    }
    
    fileprivate func _constructStrategy(paymentChannelStrategy: PaymentStrategyProtocol?, concurrentCalls: Int = 1) -> PaymentStrategyProtocol {
        guard let strategy = paymentChannelStrategy else {
            guard let strategy = self._paymentChannelManagementStrategy else {
                return DefaultPaymentStrategy(concurrentCalls: concurrentCalls)
            }
            return strategy
        }
        return strategy
    }
}
