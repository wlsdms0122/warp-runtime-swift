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
    // Each part is read out of line, so a level of calls nested to the bound
    // spends little stack, a debug build's included.
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "call")

        let arguments = try Self.arguments(in: decoder)

        guard let selector = try Self.selector(in: decoder) else {
            self.expression = .apply(try Self.callee(in: decoder), arguments: arguments)

            return
        }

        self.expression = .call(Call(selector: selector, arguments: arguments))
    }

    // MARK: - Public
    // MARK: - Private
    private static func arguments(in decoder: Decoder) throws -> [Warp.Expression] {
        try decoder.descendingIfPresent(to: CodingKeys.arguments)?
            .read([ExpressionReader].self)
            .map(\.expression) ?? []
    }

    // The declaration a string names, or nil where `procedure` is an
    // expression.
    private static func selector(in decoder: Decoder) throws -> Name? {
        guard let spelled = try? decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .procedure) else {
            return nil
        }

        return decoder.notation.qualified(try Name.read(spelled, at: decoder.steps), as: .procedure)
    }

    private static func callee(in decoder: Decoder) throws -> Warp.Expression {
        try decoder.descending(to: CodingKeys.procedure).read(ExpressionReader.self).expression
    }
}
