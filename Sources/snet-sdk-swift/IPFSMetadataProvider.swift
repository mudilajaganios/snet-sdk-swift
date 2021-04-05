//
//  IPFSMetadataProvider.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 17/03/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import PromiseKit
import snet_contracts
//#if os(macOS)
//import snet_swift_pkg_macOS
//#else
//import snet_swift_pkg_iOS
//#endif

///This class uses the HTTP API interface for the IPFS
public class IPFSMetadataProvider {
    
    private let web3Instance: Web3
    private let networkId: String
    private let ipfsEndpoint: String
    private var registryContract: DynamicContract?
    private var ethereumAddress: EthereumAddress?
    
    init(web3: Web3, networkId: String, ipfsEndpoint: String) {
        self.web3Instance = web3
        self.networkId = networkId
        self.ipfsEndpoint = ipfsEndpoint
        
        let networkAddress = SNETContracts.shared.getNetworkAddress(networkId: networkId)

        guard let abiContractData = SNETContracts.shared.abiContract() else {
            return
        }

        self.ethereumAddress = EthereumAddress(hexString: networkAddress)
        self.registryContract = try? self.web3Instance.eth.Contract(json: abiContractData, abiKey: nil, address: self.ethereumAddress)
    }
    
    func metadata(orgId: String, serviceId: String) -> Promise<[String: Any]> {
        let orgMetadata = self._fetchOrgMetadata(orgId: orgId)
        let serviceMetadata = self._fetchServiceMetadata(orgId: orgId, serviceId: serviceId)

        return firstly {
            when(fulfilled: orgMetadata, serviceMetadata)
        }.then { (orgmetadata, servicemetadata) -> Promise<[String: Any]> in
           return self._enhanceServiceGroupDetails(serviceMetadata: servicemetadata, orgMetadata: orgmetadata)
        }
    }
    
    func getOrgsList() -> Promise<[String: Any]> {
        guard let contract = self.registryContract else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        
        return contract["listOrganizations"]!().call()
    }
    
    fileprivate func _fetchOrgMetadata(orgId: String) -> Promise<[String: Any]> {
        guard let orgIDBytes = orgId.data(using: .ascii),
              let contract = self.registryContract else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return firstly {
            contract["getOrganizationById"]!(orgIDBytes).call()
        }.then({ (data) -> Promise<[String: Any]> in
            let orgMetadataURI = data["orgMetadataURI"] as? Data
            return self._fetchMetadataFromIpfs(metadataURI: orgMetadataURI!)
        })
    }
    
    fileprivate func _fetchServiceMetadata(orgId: String, serviceId: String) -> Promise<[String: Any]> {
        guard let orgIDBytes = orgId.data(using: .utf8),
              let serviceIDBytes = serviceId.data(using: .utf8),
              let contract = self.registryContract else {
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        
        return firstly {
            contract["getServiceRegistrationById"]!(orgIDBytes, serviceIDBytes).call()
        }.then({ (data) -> Promise<[String: Any]> in
            let serviceMetadataURI = data["metadataURI"] as? Data
            return self._fetchMetadataFromIpfs(metadataURI: serviceMetadataURI!)
        })
    }
    
    fileprivate func _enhanceServiceGroupDetails(serviceMetadata: [String: Any], orgMetadata: [String: Any]) -> Promise<[String: Any]> {
        return Promise { result in
            guard let orgGroups = orgMetadata["groups"] as? [[String: Any]] else {
                return result.fulfill(serviceMetadata)
            }
            
            var mutableServiceMetadata = serviceMetadata
            guard var mutableServiceGroups = serviceMetadata["groups"] as? [[String: Any]] else {
                return result.fulfill(serviceMetadata)
            }
            
            orgGroups.forEach { (group) in
                if let serviceGroups = serviceMetadata["groups"] as? [[String: Any]], serviceGroups.count > 0 {
                    for (index, serviceGroup) in serviceGroups.enumerated() {
                        if let serviceGroupName = serviceGroup["group_name"] as? String,
                           let orgGroupName = group["group_name"] as? String,
                           serviceGroupName == orgGroupName {
                            mutableServiceGroups[index]["payment"] = group["payment"]
                        }
                    }
                }
            }
            
            mutableServiceMetadata["groups"] = mutableServiceGroups
            result.fulfill(mutableServiceMetadata)
        }
    }
    
    fileprivate func _fetchMetadataFromIpfs(metadataURI: Data) -> Promise<[String: Any]> {
        return Promise { fetch in
            var urlComponents = URLComponents(string: "\(DefaultConfig.ipfsEndpoint)/api/v0/cat")
            let utfString = String(data:metadataURI, encoding: .ascii)
            let shortenString = utfString!.toLengthOf(length: 7).replacingOccurrences(of: "\0", with: "")
            urlComponents?.queryItems = [
                URLQueryItem(name: "arg", value: shortenString)
            ]
            
            var urlRequest = URLRequest(url: (urlComponents?.url)!)
            urlRequest.httpMethod = "POST"
            
            URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                if error != nil {
                    fetch.reject(error!)
                }
                
                guard let data = data,
                      let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    fetch.reject(error ?? genericError)
                    return
                }
                
                fetch.fulfill(result)
            }.resume()
        }
    }
}
