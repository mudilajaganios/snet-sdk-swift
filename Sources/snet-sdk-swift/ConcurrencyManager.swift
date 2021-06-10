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
                self._getTokenForAmount(channel: channel, amount: currentSignedAmount)
            }.then { tokenResponse -> Promise<String> in
                if tokenResponse.usedAmount < tokenResponse.plannedAmount {
                    return Promise.value(tokenResponse.token)
                } else {
                    let newAmountToBeSigned = currentSignedAmount + serviceCallPrice
                    return self._getNewToken(channel: channel, amount: newAmountToBeSigned)
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
                
        return firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.then { blockNumber -> Promise<Escrow_TokenRequest> in
            let mpeSignature = self._generateMpeSignature(channelId: channel.channelId, nonce: nonce, signedAmount: amount)
            let tokenSignature = self._generateTokenSignature(mpeSignature: mpeSignature, currentBlockNumber: blockNumber.quantity)
            
            var request = Escrow_TokenRequest()
            request.channelID = try! UInt64(channel.channelId)
            request.currentNonce = try! UInt64(nonce)
            request.signedAmount = try! UInt64(amount)
            request.signature = Data(hex: tokenSignature)
            request.currentBlock = try! UInt64(blockNumber.quantity)
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
            
            do {
                let token = try tokenCall.response.wait()
                return Promise.value(token)
            } catch {
                return Promise { errorreturn in
                    errorreturn.reject(error)
                }
            }
        }
    }
    
    fileprivate func _generateTokenSignature(mpeSignature: String, currentBlockNumber: BigUInt) -> String {
        let hexString = mpeSignature
            + String(currentBlockNumber, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        return self._serviceClient.sign(dataToSign: hexString)
    }
    
    fileprivate func _generateMpeSignature(channelId: BigUInt, nonce: BigUInt, signedAmount: BigUInt) -> String {
        let hexString = "__MPE_claim_message".tohexString()
            + self._serviceClient.mpeContract.address!.hex(eip55: false).replacingOccurrences(of: "0x", with: "")
            + String(channelId, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + String(nonce, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + String(signedAmount, radix: 16).paddingLeft(toLength: 64, withPad: "0")
        return self._serviceClient.sign(dataToSign: hexString)
    }
}
