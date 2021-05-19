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
    
    //TODO: Sign the message against private key
    public func signData(sha3Message: Data) -> Data {
        do {
            let privateKey = try EthereumPrivateKey(hexPrivateKey: self._privateKey)
            let signedMessage = try privateKey.sign(message: sha3Message.bytes)
            let signature = signedMessage.r.toHexString() + signedMessage.s.toHexString() + String(format:"%02x", signedMessage.v+27)
            return Data(hex: signature)
        } catch {
            print(error)
        }
        return Data()
    }
//
//
//
//        let bytes = self._privateKey.hexToBytes()
//
//        let secKeyData = Data(bytes)
//
////        let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAlways, [.privateKeyUsage], nil)
//
////        let accessControl = SecAccessControlCreateWithFlags(
////                    kCFAllocatorDefault,
////                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
////                    nil)
//
////        guard let secKeyData =  self._privateKey.data(using: .ascii) else {
////                print("Error: invalid encodedKey, cannot extract data")
////                return Data()
////            }
//            let attributes =
//            [
//                kSecAttrIsPermanent:false,
//                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
//                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
////                kSecAttrAccessControl:accessControl
//            ] as [String: Any]
//
//        var keyerror: Unmanaged<CFError>?
//
////        let key = SecKeyCreateRandomKey(attributes as CFDictionary, &keyerror)
////        print(keyerror)
//
//        guard let secKey = SecKeyCreateWithData(secKeyData as CFData, attributes as CFDictionary, &keyerror) else {
//            print(keyerror)
//                print("Error: Problem in SecKeyCreateWithData()")
//                return Data()
//        }
//
//        var algorithm: SecKeyAlgorithm = .rsaSignatureDigestPKCS1v15SHA256
//
//        if #available(macOS 10.13, *) {
//            algorithm = .rsaSignatureMessagePSSSHA256
//        }
//
//        var error: Unmanaged<CFError>?
//
//        guard let signedData = SecKeyCreateSignature(secKey, algorithm, sha3Message as CFData, &error) as Data? else {
//            print(error)
//            return Data()
//        }
//
//        return signedData
//    }
    
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
