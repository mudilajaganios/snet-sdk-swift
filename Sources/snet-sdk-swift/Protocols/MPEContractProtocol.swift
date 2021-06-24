//
//  MPEContractProtocol.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 15/06/2021.
//

import Foundation
import PromiseKit
import Web3

protocol MPEContractProtocol {
    
    var address: EthereumAddress? { get }
    
    func channels(channelId: BigUInt) -> Promise<[String: Any]>
    func getPastOpenChannels(account: AccountProtocol, service: ServiceClientStateProtocol, startingBlockNumber: EthereumQuantity?) -> Promise<[PaymentChannel]>
    func openChannel(account: AccountProtocol, service: ServiceClientStateProtocol, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData>
    func depositAndOpenChannel(account: AccountProtocol, service: ServiceClientStateProtocol, amountInCogs: BigUInt, expiry: BigUInt) -> Promise<EthereumData>
    func balance(of address: EthereumAddress) -> Promise<[String: Any]>
    func deposit(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData>
    func withdraw(account: AccountProtocol, amountInCogs: BigUInt) -> Promise<EthereumData>
    
    func channelAddFunds(account: AccountProtocol, channelId: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData>
    func channelExtend(account: AccountProtocol, channelId: BigUInt, expiry: BigUInt) -> Promise<EthereumData>
    func channelExtendAndAddFunds(account: AccountProtocol, channelId: BigUInt, expiry: BigUInt, amountInCogs: BigUInt) -> Promise<EthereumData>
    func channelClaimTimeout(account: AccountProtocol, channelId: BigUInt) -> Promise<EthereumData>
}
