//
//  BasePaidPaymentStrategy.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 23/04/2021.
//

import Foundation

class BasePaidPaymentStrategy: PaymentChannelProtocol {
    
    fileprivate let _serviceClient: ServiceClient
    fileprivate let _blockOffset: Int
    fileprivate let _callAllowance: Int
    
    init(serviceClient: ServiceClient, blockOffset: Int = 240, callAllowance: Int = 1) {
        self._serviceClient = serviceClient;
        self._blockOffset = blockOffset;
        self._callAllowance = callAllowance;
    }
    
    func _selectChannel() {
        
    }
    
    func _getPrice() {
        
    }
    
    func _doesChannelHaveSufficientFunds() {
        
    }
    
    func _isValidChannel() {
        
    }
    
    func getPaymentMetadata() {
        
    }
}
