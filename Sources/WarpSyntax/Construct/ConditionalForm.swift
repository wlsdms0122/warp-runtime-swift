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

    private let condition: Warp.Expression
    private let then: Body
    private let otherwise: Body?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "conditional")

        self.condition = try decoder.descending(to: CodingKeys.when).read(ExpressionReader.self).expression
        self.then = try decoder.descending(to: CodingKeys.then).read(BodyReader.self).body
        self.otherwise = try decoder.descendingIfPresent(to: CodingKeys.else)?.read(BodyReader.self).body
    }

    // MARK: - Public
    // A name on a conditional is `Validator`'s to refuse (`answersNothing`),
    // whichever notation spelled it.
    public func expression(boundTo name: String?) -> Warp.Expression {
        .conditional(condition, then: then, else: otherwise)
    }

    // MARK: - Private
}
