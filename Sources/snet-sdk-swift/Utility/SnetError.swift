//
//  SnetError.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 20/06/2021.
//

import Foundation

public enum SnetError: Error {
    case failedIPFSCall
    case failedContractInit(String)
    case failedEthereumCall
    case dataNotAvailable(String)
    case failedConversion(String)
    case unexpected(code: Int)
}

extension SnetError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .failedIPFSCall:
            return "Failed to fetch metadata from IPFS"
        case .failedContractInit(let contractname):
            return "Failed to initialize the \(contractname) contract"
        case .failedEthereumCall:
            return "Failed Ethereum Call"
        case .dataNotAvailable(let dataname):
            return dataname
        case .failedConversion(let details):
            return details
        case .unexpected(_):
            return "An unexpected error occurred"
        default:
            return ""
        }
    }
}

extension SnetError: LocalizedError {
    public var errorDescription: String? {
        return debugDescription
    }
}
