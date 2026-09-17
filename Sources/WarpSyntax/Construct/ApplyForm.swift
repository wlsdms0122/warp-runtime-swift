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
// both under one key would hide which of those an author had written.
//
// The spelling is not negotiated with whoever else wants the key. A key
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

        self.callee = try decoder.descending(to: CodingKeys.procedure).read(ExpressionReader.self).expression
        self.arguments = try decoder.descendingIfPresent(to: CodingKeys.arguments)?
            .read([String: ExpressionReader].self)
            .mapValues(\.expression)
            .named(at: decoder.steps) ?? [:]
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .apply(callee, arguments: arguments)
    }

    // MARK: - Private
}
