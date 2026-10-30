//
//  TryForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A body run under a catch. What it guards is a body rather than a statement,
// so an author writes the span they mean instead of marking each statement in
// it.
//
// While the catch runs, the failure is a value under the try's own name.
struct TryForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case body
        case `catch`
    }

    // MARK: - Property
    static let key: Name = "try"

    private let tried: Body
    private let `catch`: Body

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "try")

        self.tried = try decoder.descending(to: CodingKeys.body).read(BodyReader.self).body
        self.catch = try decoder.descending(to: CodingKeys.catch).read(BodyReader.self).body
    }

    // MARK: - Public
    func expression(boundTo name: Name?) -> Warp.Expression {
        .try(tried, catch: `catch`)
    }

    // MARK: - Private
}
