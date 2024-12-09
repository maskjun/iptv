//
//  Item.swift
//  iptv
//
//  Created by 马军 on 2024/12/9.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
