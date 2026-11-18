//
//  TypeExpression+Accepting.swift
//  WarpTests
//
//  Created by JSilver on 10/12/26.
//

import Foundation
@testable import Warp

extension TypeExpression {
    // Whether a value of `other` may stand where this is declared, by the
    // judgement the build and the doors ask, over the table the types' names
    // stand in.
    func accepts(_ other: TypeExpression, in types: TypeTable = .empty) -> Bool {
        lowered(in: types.loweredTypes).accepts(other.lowered(in: types.loweredTypes), in: types.loweredTypes)
    }
}
