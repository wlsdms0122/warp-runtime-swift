//
//  Notation+Testing.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

extension Notation {
    // What these tests read with. The procedures are the standard ones because the
    // fixtures link against the standard modules, not because this notation
    // knows anything about them.
    static let testing = Notation(
        spelling: TestConditionSpelling(),
        interpolation: Interpolation(read: "std.text.text", joined: "std.text.joined")
    )
}
