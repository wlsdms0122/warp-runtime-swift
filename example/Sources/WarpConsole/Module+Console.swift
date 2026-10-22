//
//  Module+Console.swift
//  WarpConsole
//

import Foundation
import Warp

public extension Module {
    // What a terminal lends a program: the key pressed, text written and the
    // screen cleared. Every one reaches outside the run, so every one is an
    // effect. The host's environment adopts `ConsoleLending`.
    static func console() throws -> Module {
        try Module(
            procedures: [
                "IO.key": Procedure(
                    signature: Signature(of: KeyEffect.self, returns: .nullable(.string)),
                    implementation: .effect(KeyEffect())
                ),
                "IO.write": Procedure(
                    signature: Signature(of: WriteEffect.self, returns: .null),
                    implementation: .effect(WriteEffect())
                ),
                "IO.clear": Procedure(
                    signature: Signature(of: ClearEffect.self, returns: .null),
                    implementation: .effect(ClearEffect())
                )
            ]
        )
    }
}
