//
//  AccountProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 16/06/2021.
//

import Foundation
import PromiseKit
import BigInt
import Web3
import Web3ContractABI

protocol AccountProtocol {
    func balance() -> Promise<[String: Any]>
    func escrowBalance() -> Promise<[String: Any]>
    func depositToEscrowAccount(amountInCogs: BigUInt) -> Promise<EthereumData>
    func approveTransfer(amountInCogs: BigUInt) -> Promise<EthereumData>
    func allowance() -> Promise<[String: Any]>
    func withdrawFromEscrowAccount(amountInCogs: BigUInt) -> Promise<EthereumData>
    func getAddress() -> EthereumAddress
    func getSignerAddress() -> EthereumAddress
    func sign(dataToSign: String) -> String
    func sendTransaction(toAddress: EthereumAddress, operation: SolidityInvocation) -> Promise<EthereumData>
}
