//
//  Module+File.swift
//  WarpFile
//

import Foundation
import Warp

public extension Module {
    // Files under a directory the host lends. A path is read under that
    // directory and never outside it; what the host lends is the whole of
    // what a program can reach. Every one reaches outside the run.
    static func file() throws -> Module {
        try Module(
            procedures: [
                "File.read": Procedure(
                    signature: Signature(of: ReadEffect.self, returns: .nullable(.string), failing: .these([FileFailed.type])),
                    implementation: .effect(ReadEffect())
                ),
                "File.write": Procedure(
                    signature: Signature(of: WriteEffect.self, returns: .null, failing: .these([FileFailed.type])),
                    implementation: .effect(WriteEffect())
                ),
                "File.exists": Procedure(
                    signature: Signature(of: ExistsEffect.self, returns: .bool, failing: .these([FileFailed.type])),
                    implementation: .effect(ExistsEffect())
                ),
                "File.list": Procedure(
                    signature: Signature(of: ListEffect.self, returns: .array(.string), failing: .these([FileFailed.type])),
                    implementation: .effect(ListEffect())
                )
            ]
        )
    }
}
