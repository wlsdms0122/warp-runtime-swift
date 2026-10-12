//
//  CallForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Calling a procedure, with its arguments by position. `procedure` holds a
// string or an expression: a string names a declaration the build resolves,
// and an expression is a value the run calls. A string is never a value that
// could be called, so the two readings never meet.
//
// A call names a declaration, never a document: which module declared it is
// the build's to resolve. A body a procedure is to run travels as a closure
// argument, like any other value.
struct CallForm: Decodable, Sendable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case procedure
        case arguments
    }

    // MARK: - Property
    let expression: Warp.Expression

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "call")

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let notation = decoder.notation

        let arguments = try decoder.descendingIfPresent(to: CodingKeys.arguments)?
            .read([ExpressionReader].self)
            .map(\.expression) ?? []

        guard let spelled = try? container.decode(String.self, forKey: .procedure) else {
            self.expression = .apply(
                try decoder.descending(to: CodingKeys.procedure).read(ExpressionReader.self).expression,
                arguments: arguments
            )

            return
        }

        self.expression = .call(
            Call(
                selector: notation.qualified(try Name.read(spelled, at: decoder.steps), as: .procedure),
                arguments: arguments
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
}
