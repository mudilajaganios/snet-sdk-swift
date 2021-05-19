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

class FreeCallPaymentStrategy {
    
    fileprivate unowned let _serviceClient: ServiceClient
    fileprivate let _freeCallStateServiceClient: Escrow_FreeCallStateServiceClient
    
    init(serviceClient: ServiceClient) {
        self._serviceClient = serviceClient
        
        let serviceEndpoint = serviceClient.getserviceEndPoint()
        let channel = GRPCUtility.getGRPCChannel(serviceEndpoint: serviceEndpoint)
        
        self._freeCallStateServiceClient = Escrow_FreeCallStateServiceClient(channel: channel)
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
                
                let signature = self._generateSignature(currentBlockNumber: currentBlockNumber.quantity)
                
                let metadata = [["snet-current-block-number": currentBlockNumber.quantity]
                                ,["snet-payment-channel-signature-bin": signature]
                                ,["snet-free-call-auth-token-bin": tokenToMakeFreeCall]
                                ,["snet-free-call-token-expiry-block": tokenExpiryDateBlock]
                                ,["snet-payment-type": "free-call"]
                                ,["snet-free-call-user-id": email]]
                
                metadatapromise.fulfill(metadata)
            }
        }
    }
    
    private func _getFreeCallsAvailable() -> Promise<Escrow_FreeCallStateReply> {
        return firstly {
            self._getFreeCallStateRequest()
        }.then { (request) -> Promise<Escrow_FreeCallStateReply> in
            do {
                let response = try self._freeCallStateServiceClient.getFreeCallsAvailable(request).response.wait()
                return Promise.value(response)
            } catch {
                print(error.localizedDescription)
                return Promise.value(Escrow_FreeCallStateReply())
            }
        }
    }
    
    private func _generateSignature(currentBlockNumber: BigUInt) -> Data? {
        guard let serviceDetails = self._serviceClient.getServiceDetails(),
              let orgId = serviceDetails["orgId"] as? String,
              let serviceId = serviceDetails["serviceId"] as? String,
              let groupId = serviceDetails["groupId"] as? String else { return nil }
        
        guard let configuration = self._serviceClient.getFreeCallConfiguration(),
              let email = configuration["email"] as? String,
              let tokenToMakeFreeCall = configuration["tokenToMakeFreeCall"] as? String,
              let tokenExpiryDateBlock = configuration["tokenExpiryDateBlock"] as? Int else { return nil }
        
        return self._serviceClient.sign([
            DataToSign(type: "string", value: "__prefix_free_trial"),
            DataToSign(type: "string", value: email),
            DataToSign(type: "string", value: orgId),
            DataToSign(type: "string", value: serviceId ),
            DataToSign(type: "string", value: groupId ),
            DataToSign(type: "uint256", value: Int(currentBlockNumber)),
            DataToSign(type: "bytes", value: tokenToMakeFreeCall.bytes)
        ])
    }
    
    private func _getFreeCallStateRequest() -> Promise<Escrow_FreeCallStateRequest> {
        return firstly {
            self._getFreeCallStateRequestProperties()
        }.then { (properties) -> Promise<Escrow_FreeCallStateRequest> in
            return Promise { request in
                guard let userId = properties["userId"] as? String,
                      let tokenForFreeCall = properties["tokenForFreeCall"] as? String,
                      let freecallToken = tokenForFreeCall.data(using: .utf8),
                      let tokenExpiryDateBlock = properties["tokenExpiryDateBlock"] as? Int,
                      let signature = properties["signature"] as? Data,
                      let currentBlockNumber = properties["currentBlockNumber"] as? BigUInt else {
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get properties"])
                    request.reject(genericError)
                    return
                }
                
                var freecallStateRequest = Escrow_FreeCallStateRequest()
                freecallStateRequest.userID = userId
                freecallStateRequest.tokenForFreeCall = freecallToken
                freecallStateRequest.tokenExpiryDateBlock = UInt64(tokenExpiryDateBlock)
                freecallStateRequest.signature = signature
                freecallStateRequest.currentBlock = try! UInt64(currentBlockNumber)
                request.fulfill(freecallStateRequest)
            }
        }
    }
    
    private func _getFreeCallStateRequestProperties() -> Promise<[String: Any]> {
        return firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.then { (currentBlockNumber) -> Promise<[String: Any]> in
            return Promise { promise in
                
                guard let freeCallConfiguration = self._serviceClient.getFreeCallConfiguration(),
                      let email = freeCallConfiguration["email"] as? String,
                      let tokenToMakeFreeCall = freeCallConfiguration["tokenToMakeFreeCall"] as? String,
                      let tokenExpiryDateBlock = freeCallConfiguration["tokenExpiryDateBlock"] as? Int else {
                    
                    let genericError = NSError(
                        domain: "snet-sdk",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get organization metadata"])
                    promise.reject(genericError)
                    return
                }
                
                let signature = self._generateSignature(currentBlockNumber: currentBlockNumber.quantity)
                let properties = ["currentBlockNumber": currentBlockNumber.quantity
                                  ,"signature":signature
                                  ,"userId":email
                                  ,"tokenForFreeCall":tokenToMakeFreeCall
                                  ,"tokenExpiryDateBlock":tokenExpiryDateBlock] as [String : Any]
                promise.fulfill(properties)
            }
        }
    }
}
