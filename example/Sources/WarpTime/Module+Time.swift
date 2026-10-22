//
//  Module+Time.swift
//  WarpTime
//

import Foundation
import Warp

public extension Module {
    // A clock: the moment now, and a pause. Both reach outside the run.
    static func time() throws -> Module {
        try Module(
            procedures: [
                "Time.now": Procedure(
                    signature: Signature(of: NowEffect.self, returns: .int),
                    implementation: .effect(NowEffect())
                ),
                "Time.wait": Procedure(
                    signature: Signature(of: WaitEffect.self, returns: .null),
                    implementation: .effect(WaitEffect())
                )
            ]
        )
    }
}
