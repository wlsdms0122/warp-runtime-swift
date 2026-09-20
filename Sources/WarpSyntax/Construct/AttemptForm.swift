//
//  AttemptForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A body run under a rescue. What it guards is a body rather than a statement,
// so an author writes the span they mean instead of marking each statement in
// it.
//
// While the rescue runs, the failure is a value under the attempt's own name.
public struct AttemptForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case body
        case result
        case rescue
    }

    // MARK: - Property
    public static let key: Name = "attempt"

    // The attempted body is decoded as a key that must be there, so an attempt
    // at nothing is still written with an empty one. The rescue is a block of
    // its own and reads its body as a key that may be absent.
    public static let requiresBody = true

    private let attempted: Block
    private let rescue: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "attempt")

        self.attempted = try .reading(
            body: try decoder.descending(to: CodingKeys.body).read(BodyReader.self).statements,
            result: try decoder.descendingIfPresent(to: CodingKeys.result)?
                .read(ExpressionReader.self)
                .expression,
            at: decoder.steps
        )
        self.rescue = try decoder.descending(to: CodingKeys.rescue).read(BlockReader.self).block

        // An empty rescue would swallow a failure into null without a trace. If
        // the alternate path produces nothing, the honest form is no attempt.
        guard !rescue.body.isEmpty || rescue.result != nil else {
            throw ReadingError(
                "attempt `rescue` must not be empty",
                at: decoder.steps
            )
        }
    }

    // MARK: - Public
    public func expression(boundTo id: String?) throws -> Expression {
        .attempt(attempted, rescue: rescue, failure: try named(id, in: "attempt", binding: "failure"))
    }

    // MARK: - Private
}
