//
//  SVGAVideoEntity+.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit
import SVGAPlayer

extension SVGAVideoEntity {
    var duration: TimeInterval {
        guard frames > 0, fps > 0 else { return 0 }
        return TimeInterval(frames) / TimeInterval(fps)
    }
}
