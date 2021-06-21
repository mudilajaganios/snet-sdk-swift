//
//  ChannelOpenEventParams.swift
//  snet-sdk-swift
//
//  Created by Jagan Kumar Mudila on 21/06/2021.
//

import Foundation

struct ChannelOpenEventParams: Codable {
    let address: String
    let fromBlock: String
    let toBlock: String
    let topics: [String]
}
