//
//  ReturnForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// `return:`. Leaves the procedure, with what it returns. The other two leave
// forms are `BreakForm` and `ContinueForm`.
//
//     { value: { return: { ref: answer } } }
struct ReturnForm: ConstructForm {
    // MARK: - Property
    static let key: Name = "return"

    private let value: Warp.Expression?

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        let written = try ValueReader(from: decoder).value

        // Nothing written returns `null`. What is written is read through
        // `ExpressionReader`, so what it refuses is refused about the document.
        self.value = written == .null ? nil : try ExpressionReader(from: decoder).expression
    }

    // MARK: - Public
    // Nothing is bound: a statement names the value its expression returns, and
    // this one has no value.
    func expression(boundTo name: Name?) -> Warp.Expression {
        .leave(.procedure(value))
    }

    // MARK: - Private
}
