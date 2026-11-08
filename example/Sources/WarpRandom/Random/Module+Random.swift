//
//  Module+Random.swift
//  WarpRandom
//

import Foundation
import Warp

public extension Module {
    // A die. Rolling reaches outside the run, so it is an effect.
    static func random() throws -> Module {
        try Module(
            procedures: [
                "Random.int": Procedure(
                    signature: Signature(of: IntEffect.self, returns: .int, isolation: .isolated),
                    implementation: .effect(IntEffect())
                )
            ]
        )
    }
}
