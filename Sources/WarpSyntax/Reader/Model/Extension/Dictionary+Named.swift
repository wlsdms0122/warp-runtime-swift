//
//  Dictionary+Named.swift
//  WarpSyntax
//
//  Created by JSilver on 9/27/26.
//

import Foundation
import Warp

// A document's keys as the names they stand for. Where a text becomes a
// program, a key that cannot be a name is refused here rather than carried in
// as a spelling nothing can compare, and the refusal says which key it was,
// which the reading knows and the name's own door does not.
extension Dictionary where Key == String {
    func named(at steps: [Place.Step]) throws -> [Name: Value] {
        try reduce(into: [:]) { named, entry in
            named[try Name.read(entry.key, at: steps)] = entry.value
        }
    }
}
