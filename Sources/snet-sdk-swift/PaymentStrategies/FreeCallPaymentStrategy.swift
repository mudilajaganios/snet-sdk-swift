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
    fileprivate unowned let _freeCallStateServiceClient: Escrow_FreeCallStateServiceClient!
    
    init(serviceClient: ServiceClient) {
        self._serviceClient = serviceClient
        
        let serviceEndpoint = serviceClient.getserviceEndPoint()
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
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
        
        self._freeCallStateServiceClient = Escrow_FreeCallStateServiceClient(channel: channel)
    }
    
    func isFreeCallAvailable() -> Bool {
        self._getFreeCallsAvailable()
        return true
    }
    
    func getPaymentMetadata() -> [String: Any] {
        var metadata: [String: Any] = [:]
        guard let configuration = self._serviceClient.getFreeCallConfiguration(),
              let email = configuration["email"] as? String,
              let tokenToMakeFreeCall = configuration["tokenToMakeFreeCall"] as? String,
              let tokenExpiryDateBlock = configuration["tokenExpiryDateBlock"] as? String else { return metadata }
        
        firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.done { currentBlockNumber in
            metadata["snet-current-block-number"] = currentBlockNumber
            let signature = self._generateSignature(currentBlockNumber: currentBlockNumber.quantity)
            metadata["snet-payment-channel-signature-bin"] = signature
        }
        
        metadata["snet-free-call-auth-token-bin"] = tokenToMakeFreeCall
        metadata["snet-free-call-token-expiry-block"] = tokenExpiryDateBlock
        metadata["snet-payment-type"] = "free-call"
        metadata["snet-free-call-user-id"] = email
        
        return metadata
    }
    
    private func _getFreeCallsAvailable() {
        let freeCallRequest = self._getFreeCallStateRequest()
    }
    
    private func _generateSignature(currentBlockNumber: BigUInt) -> Data? {
        guard let serviceDetails = self._serviceClient.getServiceDetails(),
              let orgId = serviceDetails["orgId"] as? String,
              let serviceId = serviceDetails["serviceId"] as? String,
              let groupId = serviceDetails["groupId"] as? String else { return nil }
        
        guard let configuration = self._serviceClient.getFreeCallConfiguration(),
              let email = configuration["email"] as? String,
              let tokenToMakeFreeCall = configuration["tokenToMakeFreeCall"] as? String,
              let tokenExpiryDateBlock = configuration["tokenExpiryDateBlock"] as? String else { return nil }
        
        return self._serviceClient.sign([
            DataToSign(t: "string", v: "__prefix_free_trial"),
            DataToSign(t: "string", v: email),
            DataToSign(t: "string", v: orgId),
            DataToSign(t: "string", v: serviceId ),
            DataToSign(t: "string", v: groupId ),
            DataToSign(t: "uint256", v: currentBlockNumber ),
            DataToSign(t: "bytes", v: "")//tokenToMakeFreeCall.substring(2, tokenToMakeFreeCall.length) ),
        ]).data(using: .utf8)
    }
    
    private func _getFreeCallStateRequest() -> Escrow_FreeCallStateRequest? {
        let properties = self._getFreeCallStateRequestProperties()
        guard let userId = properties["userId"] as? String,
              let tokenForFreeCall = properties["tokenForFreeCall"] as? Data,
              let tokenExpiryDateBlock = properties["tokenExpiryDateBlock"] as? UInt64,
              let signature = properties["signature"] as? String,
              let currentBlockNumber = properties["currentBlockNumber"] as? BigUInt else {
            return nil
        }
        
        var freecallStateRequest = Escrow_FreeCallStateRequest()
        freecallStateRequest.userID = userId
        freecallStateRequest.tokenForFreeCall = tokenForFreeCall
        freecallStateRequest.tokenExpiryDateBlock = tokenExpiryDateBlock
        freecallStateRequest.signature = signature.data(using: .utf8)!
        freecallStateRequest.currentBlock = try! UInt64(currentBlockNumber)
        return freecallStateRequest
    }
    
    private func _getFreeCallStateRequestProperties() -> [String: Any] {
        
        var properties: [String: Any] = [:]
        
        guard let freeCallConfiguration = self._serviceClient.getFreeCallConfiguration(),
              let email = freeCallConfiguration["email"] as? String,
              let tokenToMakeFreeCall = freeCallConfiguration["tokenToMakeFreeCall"] as? String,
              let tokenExpiryDateBlock = freeCallConfiguration["tokenExpiryDateBlock"] as? String else {
            return properties
        }
        
        
        firstly {
            self._serviceClient.getCurrentBlockNumber()
        }.done { currentBlockNumber in
            properties["currentBlockNumber"] = currentBlockNumber
            let signature = self._generateSignature(currentBlockNumber: currentBlockNumber.quantity)
            properties["signature"] = signature
        }
        
        properties["userId"] = email
        properties["tokenForFreeCall"] = tokenToMakeFreeCall
        properties["tokenExpiryDateBlock"] = tokenExpiryDateBlock
        
        
        return properties
    }
}
