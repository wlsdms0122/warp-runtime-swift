//
//  MappingQuery.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Reading a record as data rather than as a shape. Declared fields are read
// by name; these words read names that are data, and are how a program
// walks them without knowing what they are called.
//
// `setting` answers a new record, so an author writes a changed mapping without
// the language growing a way to write into one.
public struct MappingQuery: Query {
    public enum Reading: Sendable {
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
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .record(record) = question.receiver else { return nil }

        switch reading {
        // In name order, the order the record holds: data names hold no
        // order of its own, and a walk that answered a different order each
        // run would make a program that reads it depend on nothing an author
        // wrote.
        case .keys:
            return .array(record.names.map { name in .string(name.spelling) })

        case .values:
            return .array(record.values)

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

            // A new record: the value written was held to no declaration, so
            // whatever name the receiver settled to would say what nothing
            // checked.
            return .record(record.writing(field, with: question["value"]).named(nil))
        }
    }

    // MARK: - Private
}
