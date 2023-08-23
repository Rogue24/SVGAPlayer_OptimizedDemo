//
//  String+.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import Foundation
import CryptoKit

extension String {
    var md5 : String {
        let data = Data(self.utf8)
        let hashed = Insecure.MD5.hash(data: data)
        return hashed.map { String(format: "%02hhx", $0) }.joined()
    }
}
