//
//  String+Extension.swift
//  snet-sdk-swift
//  
//
//  Created by Jagan Kumar Mudila on 30/03/2021.
//

import Foundation

extension String {
  func toLengthOf(length:Int) -> String {
            if length <= 0 {
                return self
            } else if let to = self.index(self.startIndex, offsetBy: length, limitedBy: self.endIndex) {
                return self.substring(from: to)
            } else {
                return ""
            }
        }
}

extension String {
    func tohexString() -> String {
        guard let data = self.data(using: .utf8) else { preconditionFailure("Could not get data")}
        let hexString = data.map{ String(format:"%02x", $0) }.joined()
        return hexString
    }
    
    func utf8toHexBytes() -> [UInt8] {
        return self.tohexString().hexToBytes()
    }
    
    func utf8toBase64() -> String {
        let utf8Bytes = self.bytes
        return Data(utf8Bytes).base64EncodedString(options: .init(rawValue: 0))
    }
    
    func hextoBase64() -> String {
        let hexBytes = self.hexToBytes()
        return Data(hexBytes).base64EncodedString(options: .init(rawValue: 0))
    }
}
