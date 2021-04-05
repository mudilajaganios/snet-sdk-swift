//
//  SNETContracts.swift
//  snet-sdk-swift-fwk
//
//  Created by Jagan Kumar Mudila on 30/03/2021.
//

import Foundation

public final class SNETContracts {
    //Parsing Registry Networks
    
    public static let shared = SNETContracts()
    
    public func getNetworkAddress(networkId: String) -> String {
        guard let networksFilePath = Bundle.module.path(forResource: "Contracts/NetworksRegistry", ofType: "json"),
              let networksDetails = ParseUtility.parse(from: networksFilePath) as? [String: Any],
              let networks = networksDetails[networkId] as? [String: Any],
              let networkAddress = networks["address"] as? String else {
            preconditionFailure("Couldn't find the Network registry")
        }
        return networkAddress
    }
    
    public func abiContract() -> Data? {
        //Parsing ABI Contract JSON
        guard let abiContractFilePath = Bundle.module.path(forResource: "Contracts/ABIRegistry", ofType: "json") else { return nil }
        guard let abiContractData = ParseUtility.data(from: abiContractFilePath) else {
            preconditionFailure("Couldn't find the ABI registry")
        }
        return abiContractData
    }
}
