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
// A call names a symbol, never a document. Naming the document would write a
// linkage fact into the call site; which module declared it is the builder's
// business.
//
// It is a construct key rather than the bare name a native procedure is written
// under, because a construct key is read at decode time and a procedure's name
// is not in the registry then. It is not known until the link. A name only
// known after linking cannot be a construct key, and this procedure is what that
// costs.
//
// A body a procedure is to run travels as a closure argument like any other value. A
// call carries no body of its own kind. One channel, one rule: what crosses
// into a procedure is isolated.
public struct CallForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case procedure
        case arguments
    }

    // MARK: - Property
    public static let key: Name = "call"

    private let expression: Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "call")

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let notation = decoder.userInfo[.notation] as? Notation ?? .canonical

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
    public func expression(boundTo id: String?) -> Expression {
        expression
    }

    // MARK: - Private
}
