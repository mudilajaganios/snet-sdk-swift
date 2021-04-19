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
    
    public func createServiceClient(orgId: String, serviceId: String, groupName: String = "default_group", paymentChannelManagementStrategy: Any? = nil) -> Promise<ServiceClient> {
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
    
    public func getOrgsList() -> Promise<[String: Any]> {
        return self._metadataProvider.getOrgsList()
    }
    
    public func accountBalance() -> Promise<[String: Any]> {
        return self._account.balance()
    }
    
    public func accountAllowance() -> Promise<[String: Any]> {
        return self._account.allowance()
    }
    
    public func openChannel() -> Promise<EthereumData> {
        return firstly {
            self.createServiceClient(orgId: "6ce80f485dae487688c3a083688819bb", serviceId: "test_freecall")
        }.then { (serviceClient) -> Promise<EthereumData> in
            return self._mpeContract.openChannel(account: self.account, service: serviceClient, amountInCogs: 0, expiry: 0)
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
}
