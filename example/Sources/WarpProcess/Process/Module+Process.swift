//
//  Module+Process.swift
//  WarpProcess
//

import Foundation
import Warp

public extension Module {
    // A shell command run to completion in the directory the host lends. The
    // return value is one struct, `Process.Result`, whatever the status was.
    static func process() throws -> Module {
        try Module(
            types: [
                "Process.Result": .struct(["output": .string, "status": .int])
            ],
            procedures: [
                "Process.run": Procedure(
                    signature: Signature(of: RunEffect.self, returns: .named("Process.Result"), failing: .these([ProcessFailed.type])),
                    implementation: .effect(RunEffect())
                )
            ]
        )
    }
}
