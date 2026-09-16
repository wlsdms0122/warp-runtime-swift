//
//  RegexQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

struct RegexQuery: Query {
    typealias Parameters = StringPair

    // MARK: - Property

    // MARK: - Initializer
    // MARK: - Public
    // A pattern that does not compile is an author mistake, and a constant one
    // is knowable before the run, which is the whole reason a procedure gets to
    // check its own arguments at load.
    func validate(_ question: Question<Self>) throws {
        guard
            case let .string(pattern) = question[.value],
            (try? NSRegularExpression(pattern: pattern)) != nil
        else {
            // A procedure judging its own arguments is handed the values and not
            // where they were written; the link knows that, and says it.
            throw ValidationError("regex needs a valid string pattern", at: nil)
        }
    }

    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard let receiver = question.receiver, receiver != .null else { return .bool(false) }

        guard case let .string(pattern) = question[.value] else {
            return .bool(false)
        }

        guard case let .string(text) = receiver else {
            throw ExecutionError("regex asks \(receiver.type), expected string")
        }

        return .bool(text.range(of: pattern, options: .regularExpression) != nil)
    }

    // MARK: - Private
}
