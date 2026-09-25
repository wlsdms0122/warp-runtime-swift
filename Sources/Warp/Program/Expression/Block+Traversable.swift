//
//  Block+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Block: Traversable {}

public extension Block {
    func walked<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Node)] {
        body.walked(at: stepping(trail, .part(.body)), stepping: stepping)
            + (result.map { result in
                result.walked(at: stepping(trail, .part(.result)), stepping: stepping)
            } ?? [])
    }
}
