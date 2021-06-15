//
//  PrivateKeyIdentityProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 16/06/2021.
//

import Foundation
import Web3
import PromiseKit

protocol PrivateKeyIdentityProtocol {
    func getAddress() -> EthereumAddress
    func signData(message: String) -> String
    func sendTransaction(transactionObject: EthereumTransaction) -> Promise<EthereumData>
}
