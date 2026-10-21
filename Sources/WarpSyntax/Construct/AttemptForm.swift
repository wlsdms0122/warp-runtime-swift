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
        case rescue
    }

    // MARK: - Property
    public static let key: Name = "attempt"

    private let attempted: Body
    private let rescue: Body

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "attempt")

        self.attempted = try decoder.descending(to: CodingKeys.body).read(BodyReader.self).body
        self.rescue = try decoder.descending(to: CodingKeys.rescue).read(BodyReader.self).body
    }

    // MARK: - Public
    public func expression(boundTo name: Name?) -> Warp.Expression {
        .attempt(attempted, rescue: rescue)
    }

    // MARK: - Private
}
