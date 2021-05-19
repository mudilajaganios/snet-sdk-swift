//
//  SNETContracts.swift
//  snet-sdk-swift-fwk
//
//  Created by Jagan Kumar Mudila on 30/03/2021.
//

import Foundation

public enum ContractType: String {
    case mpe = "MultiPartyEscrow"
    case registry = "Registry"
    case agitoken = "SingularityNetToken"
}

public final class SNETContracts {
    //Parsing Registry Networks
    
    public static let shared = SNETContracts()
    
    public func getNetworks(networkId: String, contractType: ContractType) -> [String: Any] {
        guard let networksFilePath = Bundle.module.path(forResource: "networks/\(contractType.rawValue)", ofType: "json"),
              let networksDetails = ParseUtility.parse(from: networksFilePath) as? [String: Any],
              let networks = networksDetails[networkId] as? [String: Any] else {
            preconditionFailure("Couldn't find the Network registry")
        }
        return networks
    }
    
    public func getNetworkAddress(networkId: String, contractType: ContractType) -> String {
        guard let networksFilePath = Bundle.module.path(forResource: "networks/\(contractType.rawValue)", ofType: "json"),
              let networksDetails = ParseUtility.parse(from: networksFilePath) as? [String: Any],
              let networks = networksDetails[networkId] as? [String: Any],
              let networkAddress = networks["address"] as? String else {
            preconditionFailure("Couldn't find the Network registry")
        }
        return networkAddress
    }
    
    public func abiContract(contractType: ContractType) -> Data? {
        //Parsing ABI Contract JSON
        guard let abiContractFilePath = Bundle.module.path(forResource: "abi/\(contractType.rawValue)", ofType: "json") else { return nil }
        guard let abiContractData = ParseUtility.data(from: abiContractFilePath) else {
            preconditionFailure("Couldn't find the ABI registry")
        }
        return abiContractData
    }
}
