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
// Three forms rather than one under three keys, because the table maps a key
// to a form and reads back the same way. One form answering to three procedures
// could be written down but not written out. Asked which procedure means it, the
// table would have three answers and no way to say which. Three forms also make
// each procedure droppable on its own, which one would not.
//
//     { id: done,   return: { ref: answer } }
//     { id: enough, break: }
//     { id: skip,   continue: outer }
public struct ReturnForm: ConstructForm {
    // MARK: - Property
    public static let key: Name = "return"

    private let value: Expression?

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
    public func expression(boundTo id: String?) -> Expression {
        .leave(Leave(reach: .procedure, value: value))
    }

    // MARK: - Private
}
