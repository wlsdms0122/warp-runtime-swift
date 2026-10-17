//
//  LoopForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Repetition governed by a condition: the body runs while `while` holds. An
// author bounds a loop with a counter and a procedure, and the host stops one
// by cancelling the run.
public struct LoopForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case `while`
        case body
    }

    // MARK: - Property
    public static let key: Name = "loop"

    // The body is decoded as a key that must be there, so a loop with nothing
    // in it is still written with an empty one.
    public static let requiresBody = true

    private let condition: Warp.Expression
    private let body: Body

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "loop")

        self.condition = try decoder.descending(to: CodingKeys.while).read(ExpressionReader.self).expression
        self.body = try decoder.descending(to: CodingKeys.body).read(BodyReader.self).body
    }

    // MARK: - Public
    // The statement binds the round under the name it introduces, read as
    // `{ ref "<name>.index" }`, so the loop is the same whatever that name is.
    public func expression(boundTo name: Name?) -> Warp.Expression {
        .loop(while: condition, body: body)
    }

    // MARK: - Private
}
