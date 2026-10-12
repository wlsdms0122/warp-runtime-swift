//
//  ReturnForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// `return:`. Leaves the procedure, with what it answers. The other two leave
// forms are `BreakForm` and `ContinueForm`.
//
//     { value { return { ref "answer" } } }
public struct ReturnForm: ConstructForm {
    // MARK: - Property
    public static let key: Name = "return"

    private let value: Warp.Expression?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let written = try ValueReader(from: decoder).value

        // Nothing written answers `null`. What is written is read through
        // `ExpressionReader`, so what it refuses is refused about the document.
        self.value = written == .null ? nil : try ExpressionReader(from: decoder).expression
    }

    // MARK: - Public
    // Nothing is bound: a statement names what its expression answered, and this
    // one does not answer.
    public func expression(boundTo name: Name?) -> Warp.Expression {
        .leave(Leave(reach: .procedure, value: value))
    }

    // MARK: - Private
}
