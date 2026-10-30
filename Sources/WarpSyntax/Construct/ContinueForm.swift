//
//  ContinueForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// `continue:`. Ends a round of a loop: the nearest one, or the one it names.
// Which loop is read the way `BreakForm` reads it.
struct ContinueForm: ConstructForm {
    // MARK: - Property
    static let key: Name = "continue"

    private let target: Name?

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.target = try BreakForm.target(from: decoder, called: Self.key)
    }

    // MARK: - Public
    func expression(boundTo name: Name?) -> Warp.Expression {
        .leave(.round(target))
    }

    // MARK: - Private
}
