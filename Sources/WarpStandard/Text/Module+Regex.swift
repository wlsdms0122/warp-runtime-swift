//
//  Module+Regex.swift
//  WarpStandard
//
//  Created by JSilver on 9/19/26.
//

import Foundation
import Warp

public extension Module {
    // What a pattern means differs between the engines a host would reach for,
    // so this is asked of no implementation and stands beside the standard
    // bundles rather than in one: a host lays it in the link or leaves it out.
    static let regex: [Module] = [nativeRegex]

    private static let nativeRegex = try! Module(
        description: "Whether a string matches a pattern, in the host's own dialect.",
        procedures: [
            "std.text.regex": Procedure(
                description: "Whether a string matches a pattern.",
                signature: Signature(of: RegexQuery.self, receiver: .of, returns: .bool),
                implementation: .query(RegexQuery())
            )
        ],
        builtin: true
    )
}
