//
//  ApplyForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Calling a value that is a procedure.
//
// Beside `call:` rather than folded into it, because the two ask different
// questions. `call:` names a symbol, and the builder answers it before anything
// runs; this names an expression, and only a run can say what it holds. Writing
// both as one word would hide which of those an author had written.
//
// The spelling is not negotiated with whoever else wants the word. A word
// belongs to a `ConstructRegistry`, so a caller that wants `apply` for itself
// removes this one and registers its own.
public struct ApplyForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case procedure
        case arguments
    }

    // MARK: - Property
    public static let key: Name = "apply"

    private let callee: Expression
    private let arguments: [Name: Expression]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "apply")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.callee = try container.decode(ExpressionReader.self, forKey: .procedure).expression
        self.arguments = try container.decodeIfPresent(
            [String: ExpressionReader].self,
            forKey: .arguments
        )?
        .mapValues(\.expression)
        .named(at: decoder.steps) ?? [:]
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .apply(callee, arguments: arguments)
    }

    // MARK: - Private
}
