//
//  ValueTag.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// How a value is laid down in an object: its kind first, then what the kind
// holds. The object format's own list, read from either side, so the writing
// and the reading are one rule.
enum ValueTag: Int {
    case null
    case bool
    case int
    case double
    case string
    case bytes
    case array
    case record
    case dictionary
    case closure
}
