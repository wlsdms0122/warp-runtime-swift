//
//  Block+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Block: Traversable {
    func walked<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Node)] {
        body.walked(at: Child.body.steps.reduce(trail, stepping), stepping: stepping)
            + (result.map { result in
                result.walked(at: Child.result.steps.reduce(trail, stepping), stepping: stepping)
            } ?? [])
    }
}
