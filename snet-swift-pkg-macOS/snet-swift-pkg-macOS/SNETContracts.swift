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
        guard let networksFilePath = Bundle(for: SNETContracts.self).path(forResource: "NetworksRegistry", ofType: "json"),
              let networksDetails = ParseUtility.parse(from: networksFilePath) as? [String: Any],
              let networks = networksDetails[networkId] as? [String: Any],
              let networkAddress = networks["address"] as? String else {
            return ""
        }
        return networkAddress
    }
    
    public func abiContract() -> Data? {
        //Parsing ABI Contract JSON
        guard let abiContractFilePath = Bundle(for: SNETContracts.self).path(forResource: "ABIRegistry", ofType: "json") else { return nil }
        guard let abiContractData = ParseUtility.data(from: abiContractFilePath) else {
            return nil
        }
        return abiContractData
    }
}
