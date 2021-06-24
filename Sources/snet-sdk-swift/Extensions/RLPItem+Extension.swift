//
//  RLPItem+Extension.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 16/06/2021.
//

import Foundation
import Web3

extension RLPItem {
    /**
     * Create an RLPItem representing a transaction. The RLPItem must be an array of 6 items in the proper order.
     *
     * - parameter nonce: The nonce of this transaction.
     * - parameter gasPrice: The gas price for this transaction in wei.
     * - parameter gasLimit: The gas limit for this transaction.
     * - parameter to: The address of the receiver.
     * - parameter data: Input data for this transaction.
     */
    init(
        nonce: EthereumQuantity,
        gasPrice: EthereumQuantity,
        gasLimit: EthereumQuantity,
        to: EthereumAddress?,
        data: EthereumData,
        chainId: UInt
    ) {
        self = .array(
            .bigUInt(nonce.quantity),
            .bigUInt(gasPrice.quantity),
            .bigUInt(gasLimit.quantity),
            .bytes(to?.rawAddress ?? Bytes()),
            .string(""),
            .bytes(data.bytes),
            .init(integerLiteral: chainId),
            .init(integerLiteral: 0),
            .init(integerLiteral: 0)
        )
    }
}
