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
    private let _mpeContract: MPEContract
    private let _account: Account
    
    private var _paymentChannelManagementStrategy: Any?
    
    public init(config: SDKConfig, metadataProvider: IPFSMetadataProvider? = nil) {
        let web3 = Web3(provider: Web3HttpProvider(rpcURL: config.web3Provider))
        self._web3 = web3
        let mpeContract = MPEContract(web3: web3, networkId: config.networkId)
        self._mpeContract = mpeContract
        let identity = PrivateKeyIdentity(config: config, web3: web3)
        self._account = Account(web3: web3, networkId: config.networkId, mpeContract: mpeContract, identity: identity)
        self._metadataProvider = metadataProvider ?? IPFSMetadataProvider(web3: web3,
                                                                         networkId: config.networkId,
                                                                         ipfsEndpoint: config.ipfsEndpoint)
    }
    
    public var web3Instance: Web3 {
        return self._web3
    }
    
    public var account: Account {
        return self._account
    }
    
    public var paymentChannelManagementStrategy: Any? {
        get {
            return self._paymentChannelManagementStrategy
        }
        set {
            self._paymentChannelManagementStrategy = newValue
        }
    }
    
    func createServiceClient(orgId: String, serviceId: String, groupName: String = "default_group", paymentChannelManagementStrategy: Any? = nil) -> Promise<ServiceClient> {
        firstly {
            self._metadataProvider.metadata(orgId: orgId, serviceId: serviceId)
        }.then { (metadata) -> Promise<ServiceClient> in
            return Promise { serviceClientPromise in
                guard let group = self._serviceGroup(serviceMetadata: metadata, orgId: orgId, serviceId: serviceId, groupName: groupName) else {
                    let genericError = NSError(
                              domain: "snet-sdk",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    serviceClientPromise.reject(genericError)
                    return
                }
                let serviceClient = ServiceClient(sdk: self, orgId: orgId, serviceId: serviceId,
                                                  mpeContract: self._mpeContract,
                                                  metadata: metadata,
                                                  group: group,
                                                  paymentChannelManagementStrategy: [:])
                serviceClientPromise.fulfill(serviceClient)
            }
        }
    }
    
    fileprivate func _serviceGroup(serviceMetadata: [String: Any], orgId: String, serviceId: String, groupName: String) -> [String: Any]? {
        guard let groups = serviceMetadata["groups"] as? [[String: Any]],
              let group = groups.first(where: { $0["group_name"] as! String == groupName })
              else {
            return nil
        }
        return group
    }
    
    fileprivate func _constructStrategy(paymentChannelStrategy: Any?, concurrentCalls: Bool = true) -> Any {
        guard let strategy = paymentChannelStrategy else {
            guard let strategy = self._paymentChannelManagementStrategy else {
                return DefaultPaymentStrategy(concurrentCalls: concurrentCalls)
            }
            return strategy
        }
        return strategy
    }
}
