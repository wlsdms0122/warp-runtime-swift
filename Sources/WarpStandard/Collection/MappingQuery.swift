//
//  MappingQuery.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Reading a record as data rather than as a shape. Declared fields are read
// by name; these words read names that are data, and are how a program
// walks them without knowing what they are called.
//
// `setting` answers a new record, so an author writes a changed mapping without
// the language growing a way to write into one.
struct MappingQuery: Query {
    enum Reading: Sendable {
        case keys
        case values
        case setting
    }

    // MARK: - Property
    private let reading: Reading

    // MARK: - Initializer
    public init(_ reading: Reading) {
        self.reading = reading
    }

    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard let held = question.receiver?.asDictionary else { return nil }

        switch reading {
        // In name order, the order both spellings hold: a walk that answered
        // a different order each run would make a program that reads it
        // depend on nothing an author wrote.
        case .keys:
            return .array(held.names.map { name in .string(name.spelling) })

        case .values:
            return .array(held.values)

        case .setting:
            guard case let .string(key) = question["key"] else {
                throw ExecutionError("setting asks a string key")
            }

            let field: Name

            do {
                field = try Name(key)
            } catch let refusal as NameRefused {
                throw ExecutionError("setting asks a key that is a name, and \(refusal.message)")
            }

            // The names are data from here on: what was written was held to
            // no declaration, so the answer is a dictionary whatever the
            // receiver was.
            return .dictionary(held.writing(field, with: question["value"]))
        }
    }

    // MARK: - Private
}
