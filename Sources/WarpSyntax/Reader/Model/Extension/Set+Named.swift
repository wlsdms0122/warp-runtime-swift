//
//  Set+Named.swift
//  WarpSyntax
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

extension Set where Element == String {
    func named(at steps: [Place.Step]) throws -> Set<Name> {
        try reduce(into: Set<Name>()) { named, spelling in
            named.insert(try Name.read(spelling, at: steps))
        }
    }
}
