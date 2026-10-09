//
//  ReturnForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// `return:`, `break:` and `continue:`.
//
// Three forms, one to a key, since the table maps a key to a form and back,
// and each key may be dropped on its own.
//
//     { value { return { ref "answer" } } }
//     { value { break null } }
//     { value { continue "outer" } }
public struct ReturnForm: ConstructForm {
    // MARK: - Property
    public static let key: Name = "return"

    private let value: Warp.Expression?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let written = try ValueReader(from: decoder).value

        // Nothing written answers with nothing. A procedure always answers
        // something, so this is `null` rather than a procedure that does not.
        // Through the reader and not around it: what a form refuses with is a
        // refusal about a document, and only the `Decodable` boundary turns an
        // expression's own into one. Reading the value here to see whether
        // anything was written is not that boundary.
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
