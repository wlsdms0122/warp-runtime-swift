//
//  ExpressionType.swift
//  Warp
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// What the build judged an expression to hold: the type, spelled the way the
// language writes one, and the fields a dot reads on it where it holds a
// struct. A dot reads past an Optional with `?.`, so an Optional's fields are
// those of the struct it holds.
public struct ExpressionType: Sendable, Equatable {
    // A field a dot reads, and the type it holds, spelled.
    public struct Field: Sendable, Equatable {
        // MARK: - Property
        public let name: String
        public let type: String

        // MARK: - Initializer
        init(name: String, type: String) {
            self.name = name
            self.type = type
        }

        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    public let type: String

    // In the order the struct lays them out.
    public let fields: [Field]

    // MARK: - Initializer
    init(_ reading: LoweredType, in table: LoweredTypeTable) {
        self.type = reading.rendered(in: table)
        self.fields = Self.held(by: reading, in: table).map { held in
            held.named.map { name, field in Field(name: name.spelling, type: field.fieldUnwrapped.rendered(in: table)) }
        } ?? []
    }

    // MARK: - Public
    // MARK: - Private
    // The struct a dot on `reading` reads the fields of, through a name, a
    // box and an Optional.
    private static func held(by reading: LoweredType, in table: LoweredTypeTable) -> LoweredStruct? {
        switch reading {
        case let .struct(held):
            held

        case let .named(row, arguments):
            held(by: table.declared(row, applied: arguments), in: table)

        case let .optional(inner), let .variable(inner), let .inout(inner):
            held(by: inner, in: table)

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .array, .dictionary, .enum, .procedure, .parameter, .composition:
            nil
        }
    }
}
