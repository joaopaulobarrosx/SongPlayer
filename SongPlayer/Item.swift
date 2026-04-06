//
//  Item.swift
//  SongPlayer
//
//  Created by Joao Barros on 06/04/26.
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
