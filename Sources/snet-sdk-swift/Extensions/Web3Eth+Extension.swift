//
//  Web3Eth+Extension.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 21/06/2021.
//

import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit


typealias Web3ResponseCompletion<Result: Codable> = (_ resp: Web3Response<Result>) -> Void

extension Web3.Eth {
    func getPastEvents(params: ChannelOpenEventParams) -> Promise<[EthereumLogObject]> {
        return Promise { seal in
            self.getPastEvents(params: params) { response in
                response.sealPromise(seal: seal)
            }
        }
    }
    
    private func getPastEvents(params: ChannelOpenEventParams, response: @escaping Web3ResponseCompletion<[EthereumLogObject]>) {
        let req = RPCRequest<[ChannelOpenEventParams]>(
            id: properties.rpcId,
            jsonrpc: Web3.jsonrpc,
            method: "eth_getLogs",
            params: [params]
        )

        properties.provider.send(request: req, response: response)
    }
}

extension Web3Response {

    func sealPromise(seal: Resolver<Result>) {
        seal.resolve(result, error)
    }
}
