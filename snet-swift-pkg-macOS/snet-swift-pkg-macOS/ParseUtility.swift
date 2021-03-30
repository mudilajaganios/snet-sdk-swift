//
//  ParseUtility.swift
//  snet-sdk-swift-fwk
//
//  Created by Jagan Kumar Mudila on 30/03/2021.
//

import Foundation

class ParseUtility {
    static func parse(from filepath: String) -> [AnyHashable: Any]? {
        let fileURL = URL(fileURLWithPath: filepath)
        guard let fileData = try? Data(contentsOf: fileURL),
              let parsedData = try? JSONSerialization.jsonObject(with: fileData,
                                                            options: .allowFragments) as? [AnyHashable: Any] else { return nil }
        return parsedData
    }
    
    static func parseObject<T: Decodable>(from filepath: String) -> T? {
        let fileURL = URL(fileURLWithPath: filepath)
        guard let fileData = try? Data(contentsOf: fileURL),
              let parsedData = try? JSONDecoder().decode(T.self, from: fileData) as? T else { return nil }
        return parsedData
    }
    
    static func string(from filepath: String) -> String? {
        let fileURL = URL(fileURLWithPath: filepath)
        guard let fileData = try? Data(contentsOf: fileURL) else { return nil }
        let parsedString = String(data: fileData, encoding: .utf8)
        return parsedString
    }
    
    static func data(from filepath: String) -> Data? {
        let fileURL = URL(fileURLWithPath: filepath)
        let fileData = try? Data(contentsOf: fileURL)
        return fileData
    }
}

