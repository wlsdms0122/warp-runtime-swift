//
//  ConditionalForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// A conditional is a statement: the condition chooses a way through the body, and
// nothing is answered. Its arms are statement sequences (what an arm keeps it
// writes to an outer variable, and a value leaves through `return`) so there is
// no name to bind and the form takes none.
public struct ConditionalForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case when
        case then
        case `else`
    }

    // MARK: - Property
    public static let key: Name = "conditional"

    // The condition slot may be written in spellings a notation named itself, so
    // the procedures behind them are owed wherever this form is registered and
    // nowhere else. Which procedures those are is never this form's business.
    public static let readsCondition = true

    private let condition: Expression
    private let then: [Statement]
    private let otherwise: [Statement]?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "conditional")

        self.condition = try decoder.descending(to: CodingKeys.when).read(ConditionReader.self).condition
        self.then = try decoder.descending(to: CodingKeys.then).read(BodyReader.self).statements
        self.otherwise = try decoder.descendingIfPresent(to: CodingKeys.else)?.read(BodyReader.self).statements
    }

    // MARK: - Public
    // The namelessness is not this form's to enforce. `StatementReader` asks
    // the expression itself (`answersNothing`), so a notation's own spelling of a
    // conditional is held to the same rule without remembering it.
    public func expression(boundTo id: String?) -> Expression {
        .conditional(condition, then: then, else: otherwise)
    }

    // MARK: - Private
}
