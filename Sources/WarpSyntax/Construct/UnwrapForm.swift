//
//  UnwrapForm.swift
//  WarpSyntax
//
//  Created by JSilver on 10/23/26.
//

import Foundation
import Warp

// An Optional taken apart: while `then` runs, the payload is a value under the
// unwrap's own name, and a none takes `else`. Written with no `then`, the name
// holds the payload for the statements after it, and `else` leaves.
struct UnwrapForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case of
        case then
        case `else`
    }

    // MARK: - Property
    static let key: Name = "unwrap"

    private let unwrapped: Warp.Expression
    private let then: Body?
    private let otherwise: Body?

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "unwrap")

        self.unwrapped = try decoder.descending(to: CodingKeys.of).read(ExpressionReader.self).expression
        self.then = try decoder.descendingIfPresent(to: CodingKeys.then)?.read(BodyReader.self).body
        self.otherwise = try decoder.descendingIfPresent(to: CodingKeys.else)?.read(BodyReader.self).body
    }

    // MARK: - Public
    // An unwrap with neither way is `Validator`'s to refuse.
    func expression(boundTo name: Name?) -> Warp.Expression {
        .unwrap(unwrapped, then: then, else: otherwise)
    }

    // MARK: - Private
}
