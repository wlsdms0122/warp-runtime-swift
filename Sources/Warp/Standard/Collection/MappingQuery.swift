//
//  MappingQuery.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Reading an object as data rather than as a shape. A record's fields are
// declared and read by name; an object's are data, and these are how a program
// walks them without knowing what they are called.
//
// `setting` answers a new object, so an author writes a changed mapping without
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
        // In name order, the order the record holds: an object holds no
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

            // The key becomes a field's name, and is held to what a name
            // is like any other a program writes.
            let field: Name

            do {
                field = try Name(key)
            } catch let refusal as NameRefused {
                throw ExecutionError("setting asks a key that is a name, and \(refusal.message)")
            }

            // A new object: the value written was held to no declaration, so
            // whatever name the receiver settled to would say what nothing
            // checked.
            return .record(record.writing(field, with: question["value"]).named(nil))
        }
    }

    // MARK: - Private
}
