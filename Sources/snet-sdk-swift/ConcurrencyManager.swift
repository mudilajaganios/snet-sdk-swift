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
    
    init(concurrentCalls: Int = 1, serviceClient: ServiceClient) {
        self._concurrentCalls = concurrentCalls
        self._serviceClient = serviceClient
    }
    
    internal var concurrentCalls: Int {
        return self._concurrentCalls
    }
    
    func getToken(channel: PaymentChannel, serviceCallPrice: BigUInt) -> Promise<String> {
        guard let currentSignedAmount = channel.state["currentSignedAmount"] else {
            preconditionFailure("Current Signed Amount is missing")
        }
        
        if currentSignedAmount != 0 {
            return firstly {
                self._getTokenForAmount(channel: channel, amount: 0)
            }.then { tokenResponse -> Promise<String> in
                if tokenResponse.usedAmount < tokenResponse.plannedAmount {
                    return Promise.value(tokenResponse.token)
                } else {
                    return Promise.value(String())
                }
            }
        }
        
        let newAmountToBeSigned = currentSignedAmount + serviceCallPrice
        return self._getNewToken(channel: channel, amount: newAmountToBeSigned)
    }
    
    fileprivate func _getNewToken(channel: PaymentChannel, amount: BigUInt) -> Promise<String> {
        return firstly {
            self._getTokenForAmount(channel: channel, amount: amount)
        }.then { tokenResponse -> Promise<String> in
            return Promise.value(tokenResponse.token)
        }
    }
    
    fileprivate func _getTokenServiceRequest(channel: PaymentChannel, amount: BigUInt) -> Promise<Escrow_TokenRequest> {
        guard let nonce = channel.state["nonce"] else { preconditionFailure("nonce is not available")}
        guard let channelId = UInt64(channel.channelId) else { preconditionFailure("Channel id is not provided") }
        
        var currentBlockNumber: BigUInt = 0
        
        return firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.then { blockNumber -> Promise<Escrow_TokenRequest> in
            currentBlockNumber = blockNumber.quantity
            
            let mpeSignature = self._generateMpeSignature(channelId: channelId, nonce: nonce, signedAmount: amount)
            let tokenSignature = self._generateTokenSignature(mpeSignature: mpeSignature, currentBlockNumber: currentBlockNumber)
            
            var request = Escrow_TokenRequest()
            request.channelID = channelId
            request.currentNonce = UInt64(Int(nonce))
            request.signedAmount = UInt64(Int(amount))
            request.signature = Data(hex: tokenSignature)
            request.currentBlock = UInt64(Int(currentBlockNumber))
            request.claimSignature = Data(hex: mpeSignature)
            
            return Promise.value(request)
        }
    }
    
    fileprivate func _getTokenForAmount(channel: PaymentChannel, amount: BigUInt) -> Promise<Escrow_TokenReply> {
        return firstly {
            self._getTokenServiceRequest(channel: channel, amount: amount)
        }.then { serviceRequest -> Promise<Escrow_TokenReply> in
            let serviceEndpoint = self._serviceClient.getserviceEndPoint()
            let channel = GRPCUtility.getGRPCChannel(serviceEndpoint: serviceEndpoint)
            
            let tokenServiceClient = Escrow_TokenServiceClient(channel: channel)
            let tokenCall = tokenServiceClient.getToken(serviceRequest)
            guard let token = try? tokenCall.response.wait() else { preconditionFailure("Unable to get token")}
            return Promise.value(token)
        }
    }
    
    fileprivate func _generateTokenSignature(mpeSignature: String, currentBlockNumber: BigUInt) -> String {
        let hexString = mpeSignature + String(currentBlockNumber, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        return self._serviceClient.sign(dataToSign: hexString)
    }
    
    fileprivate func _generateMpeSignature(channelId: UInt64, nonce: BigUInt, signedAmount: BigUInt) -> String {
        let hexString = "__MPE_claim_message".tohexString()
                    + self._serviceClient.mpeContract.address!.hex(eip55: true)
        + String(channelId, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + String(nonce, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + String(signedAmount, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        return self._serviceClient.sign(dataToSign: hexString)
    }
}
