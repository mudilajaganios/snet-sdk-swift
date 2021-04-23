//
//  ConcurrencyManager.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 22/04/2021.
//

import Foundation

class ConcurrencyManager {
    
    fileprivate let _concurrentCalls: Bool
    fileprivate unowned let _serviceClient: ServiceClient
//    fileprivate let _tokenServiceClient: Any
    
    init(concurrentCalls: Bool = true, serviceClient: ServiceClient) {
        self._concurrentCalls = concurrentCalls
        self._serviceClient = serviceClient
    }
    
    fileprivate func _getGrpcCredentials(serviceEndpoint: String) {
    }
}
