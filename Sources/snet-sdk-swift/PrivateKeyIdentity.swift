//
//  PrivateKeyIdentity.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 13/04/2021.
//

import Foundation
import Web3
import Web3PromiseKit
import PromiseKit
import CryptoKit
import CryptoSwift

class PrivateKeyIdentity {
    
    private let _privateKey: String
    private let _web3: Web3
    private var _defaultAccount: EthereumAddress!
    private let _chainId: EthereumQuantity
    
    init(config: SDKConfig, web3: Web3) {
        self._web3 = web3
        self._privateKey = config.privateKey
        
        if let chainId = try? EthereumQuantity(config.networkId) {
            self._chainId =  chainId
        } else {
            self._chainId = EthereumQuantity(integerLiteral: 0)
        }
        
        self._setupAccount()
    }
    
    public func getAddress() -> EthereumAddress {
        return self._defaultAccount
    }
    
    fileprivate func hash(message: String) -> [UInt8] {
        //Calculate hash Encoded bytes
        let messagehash = SHA3(variant: .keccak256).calculate(for: message.hexToBytes())
        let messageBuffer = Data(hex: messagehash.toHexString())
        //Append preamble (UTF-8) bytes
        let preambleString = "\u{19}Ethereum Signed Message:\n\(messagehash.count)"
        guard var preambleBuffer = preambleString.data(using: .utf8) else { return [] }
        preambleBuffer.append(messageBuffer)
        //Calculate hash
        let hash = SHA3(variant: .keccak256).calculate(for: preambleBuffer.bytes)
        return hash
    }
    
    public func signData(message: String) -> String {
        do {
            let hash = self.hash(message: message)
            //Sign hash
            guard let privateKey = self.privateKey else { return "" }
            let signedMessage = try privateKey.sign(hash: hash)
            
            //Concatenating r s v values from the signature
            let signature = "0x" + signedMessage.r.toHexString() + signedMessage.s.toHexString() + String(format:"%02x", signedMessage.v+27)
            
            return signature
        } catch {
            print(error)
        }
        return ""
    }
    
    public func sendTransaction(transactionObject: EthereumTransaction) -> Promise<EthereumData> {
        do {
            let signedTransaction = try transactionObject.signX(with: self.privateKey!)
            return _web3.eth.sendRawTransaction(transaction: signedTransaction)
        } catch {
            return Promise { error in
              let genericError = NSError(
                  domain: "snet-sdk",
                  code: 0,
                  userInfo: [NSLocalizedDescriptionKey: "Invalid data"])
              error.reject(genericError)
            }
        }
    }
    
    private func _setupAccount() {
        guard let privateKey = self.privateKey else { return }
        self._defaultAccount = privateKey.address
    }
    
    private var privateKey: EthereumPrivateKey? {
        return try? EthereumPrivateKey(hexPrivateKey: self._privateKey)
    }
}

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

extension RLPItem {
    /**
     * Create an RLPItem representing a transaction. The RLPItem must be an array of 9 items in the proper order.
     *
     * - parameter nonce: The nonce of this transaction.
     * - parameter gasPrice: The gas price for this transaction in wei.
     * - parameter gasLimit: The gas limit for this transaction.
     * - parameter to: The address of the receiver.
     * - parameter data: Input data for this transaction.
     * - parameter v: EC signature parameter v, or a EIP155 chain id for an unsigned transaction.
     * - parameter r: EC signature parameter r.
     * - parameter s: EC recovery ID.
     */
    init(
        nonce: EthereumQuantity,
        gasPrice: EthereumQuantity,
        gasLimit: EthereumQuantity,
        to: EthereumAddress?,
        data: EthereumData
    ) {
        self = .array(
            .bigUInt(nonce.quantity),
            .bigUInt(gasPrice.quantity),
            .bigUInt(gasLimit.quantity),
            .bytes(to?.rawAddress ?? Bytes()),
            .string(""),
            .bytes(data.bytes)
        )
    }
}
