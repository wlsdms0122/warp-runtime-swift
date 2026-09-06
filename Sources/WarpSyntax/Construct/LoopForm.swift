//
//  LoopForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Repetition governed by a condition: the body runs while `while` holds.
// Nothing here bounds a body that never settles. An author bounds a loop with a
// counter and a word, and a receiver stops one with cancellation.
public struct LoopForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case `while`
        case body
        case result
    }

    // MARK: - Property
    public static let key: Name = "loop"

    // The condition slot may be written in spellings a notation named itself, so
    // the words behind them are owed wherever this form is registered and
    // nowhere else. Which words those are is never this form's business.
    public static let readsCondition = true

    // The body is decoded as a key that must be there, so a loop with nothing
    // in it is still written with an empty one.
    public static let requiresBody = true

    private let condition: Expression
    private let body: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "loop")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.condition = try container.decode(ConditionReader.self, forKey: .while).condition
        self.body = try .reading(
            body: try container.decode(BodyReader.self, forKey: .body).statements,
            result: try container.decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression,
            at: decoder.steps
        )
    }

    // MARK: - Public
    // The round state is bound under the statement's own id, which is how a
    // document writes `${<id>.index}`.
    public func expression(boundTo id: String?) throws -> Expression {
        .loop(while: condition, body: body, round: try named(id, in: "loop", binding: "round"))
    }

    // MARK: - Private
}
