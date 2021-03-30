//
//  SDKConfig.swift
//  
//
//  Created by Jagan Kumar Mudila on 24/03/2021.
//

import Foundation

public struct SDKConfig {
    let web3Provider: String
    let privateKey: String
    let signerPrivateKey: String
    let networkId: String
    var ipfsEndpoint: String
    var defaultGasPrice: Int
    var defaultGasLimit: Int
    
    public init(web3Provider: String, privateKey: String, signerPrivateKey: String, networkId: String) {
        self.web3Provider = web3Provider
        self.privateKey = privateKey
        self.signerPrivateKey = signerPrivateKey
        self.networkId = networkId
        self.ipfsEndpoint = DefaultConfig.ipfsEndpoint
        self.defaultGasPrice = DefaultConfig.defaultGasPrice
        self.defaultGasLimit = DefaultConfig.defaultGasLimit
    }
    
    public init(web3Provider: String, privateKey: String, signerPrivateKey: String, networkId: String, ipfsEndpoint: String) {
        self.init(web3Provider: web3Provider, privateKey: privateKey, signerPrivateKey: signerPrivateKey, networkId: networkId)
        self.ipfsEndpoint = ipfsEndpoint
    }
    
    public init(web3Provider: String, privateKey: String, signerPrivateKey: String, networkId: String, ipfsEndpoint: String, defaultGasPrice: Int, defaultGasLimit: Int) {
        self.init(web3Provider: web3Provider, privateKey: privateKey, signerPrivateKey: signerPrivateKey, networkId: networkId, ipfsEndpoint: ipfsEndpoint)
        self.defaultGasPrice = defaultGasPrice
        self.defaultGasLimit = defaultGasLimit
    }
}
