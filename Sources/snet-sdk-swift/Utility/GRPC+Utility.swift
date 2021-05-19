//
//  GRPC+Utility.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 19/05/2021.
//

import Foundation
import NIO
import GRPC

internal class GRPCUtility {
    internal static func getGRPCChannel(serviceEndpoint: String) -> GRPCChannel {
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        defer {
            try? group.syncShutdownGracefully()
        }
        
        var channel: GRPCChannel?
        
        var port = 80
        
        if let lastIndex = serviceEndpoint.range(of: ":", options: .backwards)?.lowerBound {
            var portString = String(serviceEndpoint[lastIndex...])
            portString.removeFirst()
            port = Int(portString)!
//            let length = serviceEndpoint.count - (lastIndex + 1)
//            port = Int(serviceEndpoint.substr(lastIndex + 1, length) ?? "0") ?? 80
        }
        
        if serviceEndpoint.starts(with: "https") {
            channel = ClientConnection.secure(group: group).connect(host: serviceEndpoint, port: port)
        } else if serviceEndpoint.starts(with: "http") {
            channel = ClientConnection.insecure(group: group).connect(host: serviceEndpoint, port: port)
        }
        
        guard let channel = channel else { preconditionFailure("Channel initialization is failed")}
        return channel
    }
}
