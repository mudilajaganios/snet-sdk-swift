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
            var signature = "0x" + signedMessage.r.toHexString() + signedMessage.s.toHexString() + String(format:"%02x", signedMessage.v+27)
            
            return signature
        } catch {
            print(error)
        }
        return ""
    }
    
    public func sendTransaction(transactionObject: EthereumTransaction) -> Promise<EthereumData> {
        
        guard let nonce = transactionObject.nonce?.hex(),
              let gasPrice = transactionObject.gasPrice?.hex(),
              let gasLimit = transactionObject.gas?.hex(),
              let toAddress = transactionObject.to?.hex(eip55: false),
              let value = transactionObject.value?.hex(),
              let privateKey = self.privateKey else { return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid data"])
                error.reject(genericError)
              }
        }
        let data = transactionObject.data.hex()
        let chainId = self._chainId.hex()
        
        var transactionData = nonce + gasPrice + gasLimit + toAddress + value + data + chainId + "00" + "00"
        transactionData = transactionData.replacingOccurrences(of: "0x", with: "")
        
        guard let transactionSignature = try? privateKey.sign(message: transactionData.hexToBytes()) else {
            return Promise { error in
                let genericError = NSError(
                    domain: "snet-sdk",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                error.reject(genericError)
            }
        }
        
        let v: BigUInt
        if self._chainId.quantity == 0 {
            v = BigUInt(transactionSignature.v) + BigUInt(27)
        } else {
            let sigV = BigUInt(transactionSignature.v)
            let big27 = BigUInt(27)
            let chainIdCalc = (self._chainId.quantity * BigUInt(2) + BigUInt(8))
            v = sigV + big27 + chainIdCalc
        }
        
        let r = BigUInt(transactionSignature.r)
        let s = BigUInt(transactionSignature.s)
        
        var signatureMessage = nonce + gasPrice + gasLimit + toAddress + value + data //+ v.rlp() + r.rlp() + s.rlp()
        signatureMessage = signatureMessage.replacingOccurrences(of: "0x", with: "")
        signatureMessage = "0x" + signatureMessage
        
        return Promise { seal in
            let req = RPCRequest<String>(
                id: self._web3.properties.rpcId,
                jsonrpc: Web3.jsonrpc,
                method: "eth_sendRawTransaction",
                params: signatureMessage
            )
            self._web3.properties.provider.send(request: req, response: { response in
                seal.resolve(response.result, response.error)
            })
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
