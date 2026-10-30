//
//  LoopForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Repetition governed by a condition: the body runs while `while` holds, and
// a loop written with no `while` does not finish. An author bounds a loop
// with a counter and a procedure, and the host stops one by cancelling the
// run.
struct LoopForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case `while`
        case body
    }

    // MARK: - Property
    static let key: Name = "loop"

    private let condition: Warp.Expression?
    private let body: Body

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "loop")

        self.condition = try decoder.descendingIfPresent(to: CodingKeys.while)?.read(ExpressionReader.self).expression
        self.body = try decoder.descending(to: CodingKeys.body).read(BodyReader.self).body
    }

    // MARK: - Public
    // The statement binds the round under the name it introduces, read as
    // `{ ref: <name>.index }`, so the loop is the same whatever that name is.
    func expression(boundTo name: Name?) -> Warp.Expression {
        .loop(while: condition, body: body)
    }

    // MARK: - Private
}
