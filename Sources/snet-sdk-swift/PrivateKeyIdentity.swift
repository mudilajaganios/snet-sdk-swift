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
    
    init(config: SDKConfig, web3: Web3) {
        self._web3 = web3
        self._privateKey = config.privateKey
        self._setupAccount()
    }
    
    public func getAddress() -> EthereumAddress {
        return self._defaultAccount
    }
    
    public func signData(sha3Message: String) -> Data {
        do {
            let privateKey = try EthereumPrivateKey(hexPrivateKey: self._privateKey)
            let signedMessage = try privateKey.sign(message: sha3Message.makeBytes())
            var signature = signedMessage.r.toHexString() + signedMessage.s.toHexString() + String(format:"%02x", signedMessage.v+27)
            print("Signature:\(signature)")
            return Data(hex: signature)
        } catch {
            print(error)
        }
        return Data()
    }
    
    public func signData(message: String) -> String {
        do {
            //Calculate hash Encoded bytes
            let messagehash = SHA3(variant: .keccak256).calculate(for: message.hexToBytes())
            let messageBuffer = Data(hex: messagehash.toHexString())
            //Append preamble (UTF-8) bytes
            let preambleString = "\u{19}Ethereum Signed Message:\n\(messagehash.count)"
            guard var preambleBuffer = preambleString.data(using: .utf8) else { return "" }
            preambleBuffer.append(messageBuffer)
            //Calculate hash
            let hash = SHA3(variant: .keccak256).calculate(for: preambleBuffer.bytes)
            //Sign hash
            let privateKey = try EthereumPrivateKey(hexPrivateKey: self._privateKey)
            let signedMessage = try privateKey.sign(hash: hash)
            
            //Concatenating r s v values from the signature
            var signature = "0x" + signedMessage.r.toHexString() + signedMessage.s.toHexString() + String(format:"%02x", signedMessage.v+27)
            
            return signature
        } catch {
            print(error)
        }
        return ""
    }
    
    public func sendTransaction(transactionObject: EthereumTransaction) -> Promise<EthereumData> {
        guard let privateKey = try? EthereumPrivateKey(hexPrivateKey: "0x" + self._privateKey),
              let signedTransaction = try? transactionObject.sign(with: privateKey) else {
            return Promise { error in
                let genericError = NSError(
                          domain: "snet-sdk",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        return self._web3.eth.sendRawTransaction(transaction: signedTransaction)
    }
    
    private func _setupAccount() {
        guard let privateKey = try? EthereumPrivateKey(hexPrivateKey: "0x" + self._privateKey) else { return }
        self._defaultAccount = privateKey.address
    }
}
