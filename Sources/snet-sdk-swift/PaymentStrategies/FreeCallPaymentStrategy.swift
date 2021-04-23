//
//  FreeCallPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 21/04/2021.
//

import Foundation

class FreeCallPaymentStrategy {
    
    fileprivate unowned let _serviceClient: ServiceClient
//    fileprivate unowned let _freeCallStateServiceClient
    
    init(serviceClient: ServiceClient) {
        self._serviceClient = serviceClient
    }
    
    func isFreeCallAvailable() -> Bool {
        return true
    }
    
    func getPaymentMetadata() {
        
    }
    
    private func _getFreeCallsAvailable() {
        
    }
    
    private func _generateSignature() {
        
    }
    
    private func _getFreeCallStateRequest() {
        
    }
    
    private func _getFreeCallStateRequestProperties() {
        
    }
    
    private func _generateFreeCallStateServiceClient() {
        
    }
    
    private func _getGrpcCredentials() {
        
    }
}
