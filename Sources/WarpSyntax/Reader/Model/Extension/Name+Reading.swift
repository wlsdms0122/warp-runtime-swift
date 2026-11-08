//
//  Name+Reading.swift
//  WarpSyntax
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

extension Name {
    static func read(_ spelling: String, at steps: [Place.Step]) throws -> Name {
        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw ReadingError(refusal.message, at: steps)
        }
    }
}
