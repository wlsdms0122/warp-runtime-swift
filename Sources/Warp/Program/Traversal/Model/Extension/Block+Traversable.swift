//
//  Block+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Block: Traversable {
    func walk<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        into found: inout [(Trail, Node)]
    ) {
        body.walk(at: Child.body.steps.reduce(trail, stepping), stepping: stepping, into: &found)
        result?.walk(at: Child.result.steps.reduce(trail, stepping), stepping: stepping, into: &found)
    }
}
