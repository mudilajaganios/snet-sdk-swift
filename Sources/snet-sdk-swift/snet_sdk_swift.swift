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
    
    public init(config: SDKConfig, metadataProvider: IPFSMetadataProvider? = nil) {
        let web3 = Web3(provider: Web3HttpProvider(rpcURL: config.web3Provider))
        self._web3 = web3
        self._mpeContract = MPEContract(web3: web3, networkId: config.networkId)
        self._metadataProvider = metadataProvider ?? IPFSMetadataProvider(web3: web3,
                                                                         networkId: config.networkId,
                                                                         ipfsEndpoint: config.ipfsEndpoint)
    }
    
    public var web3Instance: Web3 {
        return self._web3
    }
    
    public func createServiceClient(orgId: String, serviceId: String, groupName: String = "default_group", paymentChannelManagementStrategy: Any? = nil) -> Promise<ServiceClient> {
        firstly {
            self._metadataProvider.metadata(orgId: orgId, serviceId: serviceId)
        }.then { (metadata) -> Promise<ServiceClient> in
            return Promise { serviceClientPromise in
                let serviceClient = ServiceClient(sdk: self, orgId: orgId, serviceId: serviceId, mpeContract: self._mpeContract, metadata: metadata, group: [:], paymentChannelManagementStrategy: [:])
                serviceClientPromise.fulfill(serviceClient)
            }
        }
    }
    
    public func getOrgsList() -> Promise<[String: Any]> {
        return self._metadataProvider.getOrgsList()
    }
}
