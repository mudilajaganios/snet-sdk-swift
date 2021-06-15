//
//  EthereumTransaction+Extension.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 16/06/2021.
//

import Foundation
import Web3

extension EthereumTransaction {
    public func signX(with privateKey: EthereumPrivateKey, chainId: EthereumQuantity = 0) throws -> EthereumSignedTransaction {
        
        // These values are required for signing
        guard let nonce = nonce, let gasPrice = gasPrice, let gasLimit = gas, let value = value else {
            throw EthereumSignedTransaction.Error.transactionInvalid
        }
        
        let rlp = RLPItem(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            to: to,
            data: data
        )
        
        let rawRlp = try RLPEncoder().encode(rlp)

        guard let signedTransaction = try? privateKey.sign(message: rawRlp) else { throw EthereumSignedTransaction.Error.transactionInvalid }
                
        let v: BigUInt
        if chainId.quantity == 0 {
            v = BigUInt(signedTransaction.v) + BigUInt(27)
        } else {
            let sigV = BigUInt(signedTransaction.v)
            let big27 = BigUInt(27)
            let chainIdCalc = (chainId.quantity * BigUInt(2) + BigUInt(8))
            v = sigV + big27 + chainIdCalc
        }
        
        return EthereumSignedTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            to: to,
            value: value,
            data: data,
            v: EthereumQuantity(quantity: v),
            r: EthereumQuantity(quantity: BigUInt(signedTransaction.r)),
            s: EthereumQuantity(quantity: BigUInt(signedTransaction.s)),
            chainId: chainId
        )
    }
}
