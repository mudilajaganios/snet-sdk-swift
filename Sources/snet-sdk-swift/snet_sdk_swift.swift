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
    
    private let web3: Web3
    private let metadataProvider: IPFSMetadataProvider
    
    public init(config: SDKConfig, metadataProvider: IPFSMetadataProvider? = nil) {
        let web3 = Web3(provider: Web3HttpProvider(rpcURL: config.web3Provider))
        self.web3 = web3
        self.metadataProvider = metadataProvider ?? IPFSMetadataProvider(web3: web3,
                                                                         networkId: config.networkId,
                                                                         ipfsEndpoint: config.ipfsEndpoint)
    }
    
    public var web3Instance: Web3 {
        return self.web3
    }
    
    public func createServiceClient(orgId: String, serviceId: String, groupName: String = "default_group", paymentChannelManagementStrategy: Any? = nil) -> Promise<[String: Any]> {
        return self.metadataProvider.metadata(orgId: orgId, serviceId: serviceId)
    }
    
    public func getOrgsList() -> Promise<[String: Any]> {
        return self.metadataProvider.getOrgsList()
    }
}
