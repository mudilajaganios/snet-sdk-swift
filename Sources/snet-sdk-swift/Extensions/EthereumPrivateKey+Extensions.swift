//
//  EthereumPrivateKey+Extensions.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 17/06/2021.
//

import Foundation
import Web3
import CryptoSwift

extension EthereumPrivateKey {
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
    
    func signData(message: String) -> String {
        do {
            let hash = self.hash(message: message)
            //Sign hash
            let signedMessage = try self.sign(hash: hash)
            
            //Concatenating r s v values from the signature
            let signature = "0x" + signedMessage.r.toHexString() + signedMessage.s.toHexString() + String(format:"%02x", signedMessage.v+27)
            
            return signature
        } catch {
            print(error)
        }
        return ""
    }
}
