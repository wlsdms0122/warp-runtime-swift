//
//  Head+Lowering.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

extension Head {
    // The values this head takes as the run reads them: the type it is
    // applied as, each of its type parameters held to its bounds. Nil where
    // the head is bare, which takes every value of its type.
    func lowered(in table: LoweredTypeTable) -> LoweredType? {
        mention?.lowered(in: table, bounds: bounds)
    }
}
