//
//  FreeCallPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 21/04/2021.
//

import Foundation
import BigInt
import NIO
import GRPC
import PromiseKit
import Web3

class FreeCallPaymentStrategy {
    
    fileprivate unowned let _serviceClient: ServiceClient
    
    init(serviceClient: ServiceClient) {
        self._serviceClient = serviceClient
    }
    
    func isFreeCallAvailable() -> Promise<Bool> {
        return firstly {
            self._getFreeCallsAvailable()
        }.then { freecallsAvailable in
            return Promise.value(freecallsAvailable.freeCallsAvailable > 0)
        }
    }
    
    func getPaymentMetadata() -> Promise<[[String: Any]]> {
        return firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.then { (currentBlockNumber) -> Promise<[[String: Any]]> in
            return Promise { metadatapromise in
                guard let configuration = self._serviceClient.getFreeCallConfiguration(),
                      let email = configuration["email"] as? String,
                      let tokenToMakeFreeCall = configuration["tokenToMakeFreeCall"] as? String,
                      let tokenExpiryDateBlock = configuration["tokenExpiryDateBlock"] as? Int else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get organization metadata"])
                    metadatapromise.reject(genericError)
                    return }
                
                var signature = self._generateSignature(currentBlockNumber: currentBlockNumber.quantity)
                
                signature = signature.hextoBase64()
                
                var freeCallAuthToken = "0x" + tokenToMakeFreeCall
                
                let hexBytes2 = freeCallAuthToken.hexToBytes()
                freeCallAuthToken = Data(hexBytes2).base64EncodedString(options: .init(rawValue: 0))
                
                let metadata = [["snet-current-block-number": currentBlockNumber.quantity.description]
                                ,["snet-payment-channel-signature-bin": signature]
                                ,["snet-free-call-auth-token-bin": freeCallAuthToken]
                                ,["snet-free-call-token-expiry-block": "\(tokenExpiryDateBlock)"]
                                ,["snet-payment-type": "free-call"]
                                ,["snet-free-call-user-id": email]]
                
                metadatapromise.fulfill(metadata)
                print(metadata)
            }
        }
    }
    
    private func _getFreeCallsAvailable() -> Promise<Escrow_FreeCallStateReply> {
        return firstly {
            self._getFreeCallStateRequest()
        }.then { (request) -> Promise<Escrow_FreeCallStateReply> in
            do {
                let serviceEndpoint = self._serviceClient.getserviceEndPoint()
                let channel = GRPCUtility.getGRPCChannel(serviceEndpoint: serviceEndpoint)
                let freeCallStateServiceClient = Escrow_FreeCallStateServiceClient(channel: channel)
                let response = try freeCallStateServiceClient.getFreeCallsAvailable(request).response.wait()
                return Promise.value(response)
            } catch let error {
                print("Warning: Error occurred while checking free calls availability. \nInner Error: \(error.localizedDescription)")
                return Promise.value(Escrow_FreeCallStateReply())
            }
        }
    }
    
    private func _getFreeCallStateRequest() -> Promise<Escrow_FreeCallStateRequest> {
        return firstly {
            self._getFreeCallStateRequestProperties()
        }.then { (properties) -> Promise<Escrow_FreeCallStateRequest> in
            return Promise { request in
                var freecallStateRequest = Escrow_FreeCallStateRequest()
                freecallStateRequest.userID = properties.userId
                freecallStateRequest.tokenForFreeCall = properties.tokenforFreeCall
                freecallStateRequest.tokenExpiryDateBlock = properties.expiryBlock
                freecallStateRequest.signature = properties.signature
                freecallStateRequest.currentBlock = properties.currentBlockNumber
                request.fulfill(freecallStateRequest)
            }
        }
    }
    
    private func _getFreeCallStateRequestProperties() -> Promise<FreeCallStateRequestProperties> {
        return firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.then { (currentBlockNumber) -> Promise<FreeCallStateRequestProperties> in
            return Promise { promise in
                
                guard let freeCallConfiguration = self._serviceClient.getFreeCallConfiguration(),
                      let currentBlock = try? UInt64(currentBlockNumber.quantity),
                      let email = freeCallConfiguration["email"] as? String,
                      let tokenToMakeFreeCall = freeCallConfiguration["tokenToMakeFreeCall"] as? String,
                      let tokenExpiryDateBlock = freeCallConfiguration["tokenExpiryDateBlock"] as? Int else {
                    promise.reject(SnetError.dataNotAvailable("Free call configuration is not provided/ not in valid format"))
                    return
                }
                
                let signature = self._generateSignature(currentBlockNumber: currentBlockNumber.quantity)
                let properties = FreeCallStateRequestProperties(currentBlockNumber: currentBlock,
                                                                signature: Data(hex: signature),
                                                                userId: email,
                                                                tokenforFreeCall: Data(hex: tokenToMakeFreeCall),
                                                                expiryBlock: UInt64(tokenExpiryDateBlock))
                promise.fulfill(properties)
            }
        }
    }
    
    private func _generateSignature(currentBlockNumber: BigUInt) -> String {
        guard let serviceDetails = self._serviceClient.getServiceDetails(),
              let orgId = serviceDetails["orgId"] as? String,
              let serviceId = serviceDetails["serviceId"] as? String,
              let groupId = serviceDetails["groupId"] as? String else {
            print("Warning: Unable to read required service details. Empty signature will be generated")
            return "" }
        
        guard let configuration = self._serviceClient.getFreeCallConfiguration(),
              let email = configuration["email"] as? String,
              let tokenToMakeFreeCall = configuration["tokenToMakeFreeCall"] as? String else {
            print("Warning: Unable to read required freecall details. Empty signature will be generated")
            return "" }
        
        let hexString = "__prefix_free_trial".tohexString()
            + email.tohexString()
            + orgId.tohexString()
            + serviceId.tohexString()
            + groupId.tohexString()
            + String(currentBlockNumber, radix: 16).paddingLeft(toLength: 64, withPad: "0")
            + ("0x" + tokenToMakeFreeCall)
        
        return self._serviceClient.sign(dataToSign: hexString)
    }
    
    private struct FreeCallStateRequestProperties {
        let currentBlockNumber: UInt64
        let signature: Data
        let userId: String
        let tokenforFreeCall: Data
        let expiryBlock: UInt64
    }
}
