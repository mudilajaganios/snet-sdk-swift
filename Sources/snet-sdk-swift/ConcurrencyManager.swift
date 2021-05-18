//
//  ConcurrencyManager.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 22/04/2021.
//

import Foundation
import BigInt
import GRPC
import NIO
import PromiseKit

class ConcurrencyManager {
    
    fileprivate let _concurrentCalls: Int
    fileprivate unowned let _serviceClient: ServiceClient
    fileprivate let _tokenServiceClient: Escrow_TokenServiceClient
    
    init(concurrentCalls: Int = 1, serviceClient: ServiceClient) {
        self._concurrentCalls = concurrentCalls
        self._serviceClient = serviceClient
        let serviceEndpoint = serviceClient.getserviceEndPoint()
        
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        defer {
          try? group.syncShutdownGracefully()
        }
        
        var channel: GRPCChannel?
        
        if serviceEndpoint.starts(with: "https") {
            channel = ClientConnection.secure(group: group).connect(host: serviceEndpoint, port: 443)
        } else if serviceEndpoint.starts(with: "http") {
            channel = ClientConnection.insecure(group: group).connect(host: serviceEndpoint, port: 80)
        }
        
        guard let channel = channel else { preconditionFailure("Channel initialization is failed")}
        
        let client = Escrow_TokenServiceClient(channel: channel)
        
        self._tokenServiceClient = client
    }
    
    internal var concurrentCalls: Int {
        return self._concurrentCalls
    }
    
    func getToken(channel: PaymentChannel, serviceCallPrice: BigUInt) -> String {
        guard let currentSignedAmount = channel.state["currentSignedAmount"] as? BigUInt else {
            return ""
        }
        
        if currentSignedAmount != 0 {
            let tokenResponse = self._getTokenForAmount(channel: channel, amount: 0)
            if tokenResponse.usedAmount < tokenResponse.plannedAmount {
                return tokenResponse.token
            }
        }
        
        let newAmountToBeSigned = currentSignedAmount + serviceCallPrice
        return self._getNewToken(channel: channel, amount: newAmountToBeSigned)
    }
    
    fileprivate func _getNewToken(channel: PaymentChannel, amount: BigUInt) -> String {
        let tokenResponse = self._getTokenForAmount(channel: channel, amount: amount)
        return tokenResponse.token
    }
    
    fileprivate func _getTokenServiceRequest(channel: PaymentChannel, amount: BigUInt) -> Escrow_TokenRequest {
        guard let nonce = channel.state["nonce"] else { preconditionFailure("nonce is not available")}
        guard let channelId = try? UInt64(channel.channelId) else { preconditionFailure("Channel id is not provided") }
        
        var currentBlockNumber: BigUInt = 0
        
        firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.done { blockNumber in
            currentBlockNumber = blockNumber.quantity
        }
        
        let mpeSignature = self._generateMpeSignature(channelId: channelId, nonce: nonce, signedAmount: amount)
        let tokenSignature = self._generateTokenSignature(mpeSignature: mpeSignature, currentBlockNumber: currentBlockNumber)
        
        var request = Escrow_TokenRequest()
        request.channelID = channelId
        request.currentNonce = UInt64(Int(nonce))
        request.signedAmount = UInt64(Int(amount))
        request.signature = tokenSignature
        request.currentBlock = UInt64(Int(currentBlockNumber))
        request.claimSignature = mpeSignature
        return request
    }
    
    fileprivate func _getTokenForAmount(channel: PaymentChannel, amount: BigUInt) -> Escrow_TokenReply {
        let serviceRequest = self._getTokenServiceRequest(channel: channel, amount: amount)
        let tokenCall = self._tokenServiceClient.getToken(serviceRequest)
        guard let token = try? tokenCall.response.wait() else { preconditionFailure("Unable to get token")}
        return token
    }
    
    fileprivate func _generateTokenSignature(mpeSignature: Data, currentBlockNumber: BigUInt) -> Data {
        let data = [DataToSign(t: "bytes", v: mpeSignature),
                    DataToSign(t: "uint256", v: currentBlockNumber)]
        return self._serviceClient.sign(data)
    }
    
    fileprivate func _generateMpeSignature(channelId: UInt64, nonce: BigUInt, signedAmount: BigUInt) -> Data {
        let data = [DataToSign(t: "string", v: "__MPE_claim_message" ),
                    DataToSign( t: "address", v: self._serviceClient.mpeContract.address ),
                    DataToSign( t: "uint256", v: channelId ),
                    DataToSign( t: "uint256", v: nonce ),
                    DataToSign( t: "uint256", v: signedAmount )]
        return self._serviceClient.sign(data)
    }
}
