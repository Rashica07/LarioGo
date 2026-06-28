//
//  Item.swift
//  LarioGo
//
//  Created by user on 29.6.26.
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
