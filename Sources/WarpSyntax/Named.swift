//
//  Named.swift
//  WarpSyntax
//
//  Created by JSilver on 9/4/26.
//

import Foundation
import Warp

// A document's keys as the names they stand for. Where a text becomes a
// program, a key that cannot be a name is refused here rather than carried in
// as a spelling nothing can compare — and the refusal says which key it was,
// which the reading knows and the name's own door does not.
extension Swift.Dictionary where Key == String {
    func named(at steps: [Place.Step]) throws -> [Name: Value] {
        try reduce(into: [:]) { named, entry in
            named[try Name.read(entry.key, at: steps)] = entry.value
        }
    }
}

extension Set where Element == String {
    func named(at steps: [Place.Step]) throws -> Set<Name> {
        try reduce(into: Set<Name>()) { named, spelling in
            named.insert(try Name.read(spelling, at: steps))
        }
    }
}

extension Name {
    static func read(_ spelling: String, at steps: [Place.Step]) throws -> Name {
        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw ReadingError(refusal.message, at: steps)
        }
    }
}

extension CodingKey {
    // A notation's reserved word as the name it stands for. These spellings
    // are written in this source rather than read out of a document.
    var name: Name { Name(normal: stringValue) }
}
