//
//  SlotMark.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a slot writes in front of a whole type to say what it does with what
// fills it. The marks do not all stand in the same place (`var` is a field's
// and the other three a parameter's) and they do not all survive lowering, but
// they are spelled the same way, so the spelling is said once here and the
// reading, the writing and the document's own vocabulary are read off it.
public enum SlotMark: String, CaseIterable, Sendable {
    case variable = "var"
    case `inout`
    case consuming
    case borrowing

    // MARK: - Public
    // The type a slot marked this way holds.
    public func marking(_ inner: TypeExpression) -> TypeExpression {
        switch self {
        case .variable:
            return .variable(inner)

        case .inout:
            return .inout(inner)

        case .consuming:
            return .consuming(inner)

        case .borrowing:
            return .borrowing(inner)
        }
    }
}
