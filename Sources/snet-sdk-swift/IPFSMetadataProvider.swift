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

/// This class uses the HTTP API interface for the IPFS
class IPFSMetadataProvider {
    
    private let _web3Instance: Web3
    private let _ipfsEndpoint: String
    private var _registryContract: DynamicContract!
    
    
    /// Initializes the Metadata provider
    /// - Parameters:
    ///   - web3: Requires the web3 instance
    ///   - networkId: Requires the network id eg. "1"
    ///   - ipfsEndpoint: Requires the IPFS endpoint eg. ipfs://singularity.io
    init(web3: Web3, networkId: String, ipfsEndpoint: String) throws {
        self._web3Instance = web3
        self._ipfsEndpoint = ipfsEndpoint
        
        let networkAddress = SNETContracts.shared.getNetworkAddress(networkId: networkId, contractType: .registry)
        
        guard let abiContractData = SNETContracts.shared.abiContract(contractType: .registry) else {
            return
        }
        
        let ethereumAddress = EthereumAddress(hexString: networkAddress)
        do {
            self._registryContract = try self._web3Instance.eth.Contract(json: abiContractData,
                                                                         abiKey: nil,
                                                                         address: ethereumAddress)
        } catch  {
            throw SnetError.failedContractInit("Registry")
        }
    }
    
    
    /// Fetches metadata for the given Org Id and Service Id
    /// - Parameters:
    ///   - orgId: Organization ID
    ///   - serviceId: Service ID
    /// - Returns: Promise consists of metadata dictionary
    func metadata(orgId: String, serviceId: String) -> Promise<[String: Any]> {
        let orgMetadata = self._fetchOrgMetadata(orgId: orgId)
        let serviceMetadata = self._fetchServiceMetadata(orgId: orgId, serviceId: serviceId)
        
        return firstly {
            when(fulfilled: orgMetadata, serviceMetadata)
        }.then { (orgmetadata, servicemetadata) -> Promise<[String: Any]> in
            print("Info: Service metdata is fetched from IPFS")
            return self._enhanceServiceGroupDetails(serviceMetadata: servicemetadata, orgMetadata: orgmetadata)
        }
    }
    
    /// Pulls Organization metadata from IPFS interface
    /// - Parameters:
    ///   - orgId: Organization id provided by the client
    /// - Returns: Metadata promise
    fileprivate func _fetchOrgMetadata(orgId: String) -> Promise<[String: Any]> {
        guard let orgIDBytes = orgId.data(using: .utf8),
              let getOrganizationById = self._registryContract["getOrganizationById"] else {
            return Promise { error in
                error.reject(SnetError.failedContractInit("Registry"))
            }
        }
        return firstly {
            getOrganizationById(orgIDBytes).call()
        }.then({ (data) -> Promise<[String: Any]> in
            guard let orgMetadataURI = data["orgMetadataURI"] as? Data else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Unable to get organization URI from Registry contract"))
                }
            }
            return self._fetchMetadataFromIpfs(metadataURI: orgMetadataURI)
        })
    }
    
    
    /// Pulls Service metadata from IPFS interface
    /// - Parameters:
    ///   - orgId: Organization id provided by the client
    ///   - serviceId: Service id provided by the client
    /// - Returns: Metadata promise
    fileprivate func _fetchServiceMetadata(orgId: String, serviceId: String) -> Promise<[String: Any]> {
        guard let orgIDBytes = orgId.data(using: .utf8),
              let serviceIDBytes = serviceId.data(using: .utf8),
              let getServiceRegistrationById = self._registryContract["getServiceRegistrationById"] else {
            return Promise { error in
                error.reject(SnetError.failedConversion("Improper Org ID/ Service ID, failed to convert to Bytes"))
            }
        }
        
        return firstly {
            getServiceRegistrationById(orgIDBytes, serviceIDBytes).call()
        }.then({ (data) -> Promise<[String: Any]> in
            guard let serviceMetadataURI = data["metadataURI"] as? Data else {
                return Promise { error in
                    error.reject(SnetError.dataNotAvailable("Metadata URI is not found for Service ID"))
                }
            }
            return self._fetchMetadataFromIpfs(metadataURI: serviceMetadataURI)
        })
    }
    
    
    /// Enhancines the Service group details by adding Payment object acquired from the Organization group details
    /// - Parameters:
    ///   - serviceMetadata: Service metadata fetched from IPFS
    ///   - orgMetadata: Organization metadata fetched from IPFS
    /// - Returns: Updated Service metadata includes payment details
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
    
    
    /// Pulls the metadata from the IPFS interface
    /// - Parameter metadataURI: Metadata URI from (provided from the initializer/ default)
    /// - Returns: Metadata promise
    fileprivate func _fetchMetadataFromIpfs(metadataURI: Data) -> Promise<[String: Any]> {
        return Promise { fetch in
            var urlComponents = URLComponents(string: "\(self._ipfsEndpoint)/api/v0/cat")
            let utfString = String(data:metadataURI, encoding: .ascii)
            let shortenString = utfString!.toLengthOf(length: 7).replacingOccurrences(of: "\0", with: "")
            urlComponents?.queryItems = [
                URLQueryItem(name: "arg", value: shortenString)
            ]
            
            var urlRequest = URLRequest(url: (urlComponents?.url)!)
            urlRequest.httpMethod = "POST"
            
            URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                if error != nil {
                    fetch.reject(SnetError.failedIPFSCall)
                }
                
                guard let data = data,
                      let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
                    fetch.reject(SnetError.failedConversion("Failed to parse metadata from IPFS"))
                    return
                }
                
                fetch.fulfill(result)
            }.resume()
        }
    }
}
