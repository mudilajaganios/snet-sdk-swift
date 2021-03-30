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
