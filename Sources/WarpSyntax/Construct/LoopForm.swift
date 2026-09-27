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
// counter and a procedure, and a receiver stops one with cancellation.
public struct LoopForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case `while`
        case body
        case result
    }

    // MARK: - Property
    public static let key: Name = "loop"

    // The body is decoded as a key that must be there, so a loop with nothing
    // in it is still written with an empty one.
    public static let requiresBody = true

    private let condition: Expression
    private let body: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "loop")

        self.condition = try decoder.descending(to: CodingKeys.while).read(ExpressionReader.self).expression
        self.body = try .reading(
            body: try decoder.descending(to: CodingKeys.body).read(BodyReader.self).body,
            result: try decoder.descendingIfPresent(to: CodingKeys.result)?
                .read(ExpressionReader.self)
                .expression,
            at: decoder.steps
        )
    }

    // MARK: - Public
    // The round state is bound under the statement's own id, which is how a
    // document writes `${<id>.index}`. A nameless loop binds none.
    public func expression(boundTo id: String?) throws -> Expression {
        .loop(while: condition, body: body, round: try named(id))
    }

    // MARK: - Private
}
