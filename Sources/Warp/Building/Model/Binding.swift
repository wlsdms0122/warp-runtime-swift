//
//  Binding.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// What a name in scope is bound as, which is what a reading of the name and a
// write to it are judged against. A parameter and a constant are fixed names.
// A variable is a box: one that declared its type holds that type through
// every write, and one that did not holds what its last write put in it.
//
// `Statement.Binding` is what a statement does to its name; this is what the
// name stands as afterwards.
enum Binding: Equatable, Sendable {
    case fixed(LoweredType)
    case declared(LoweredType)
    case assigned(LoweredType)

    // MARK: - Property
    // What the name reads as, whichever way it is held.
    var type: LoweredType {
        switch self {
        case let .fixed(type), let .declared(type), let .assigned(type):
            return type
        }
    }

    // Whether a write may land on the name at all.
    var isBox: Bool {
        switch self {
        case .declared, .assigned:
            return true

        case .fixed:
            return false
        }
    }

    // MARK: - Initializer
    // A parameter as the body holds it: one handed in place is the caller's
    // box, held to its type, and any other is a fixed name.
    init(parameter declared: LoweredType) {
        switch declared {
        case let .inout(inner):
            self = .declared(inner.slotUnwrapped)

        case .any, .never, .null, .bool, .int, .double, .string, .bytes,
            .ranged, .array, .dictionary, .record, .procedure, .variable, .nullable,
            .named, .parameter, .composition, .reading, .undeclared:
            self = .fixed(declared)
        }
    }

    // MARK: - Public
    // The same name held the same way, reading as what the transform makes
    // of what it read as.
    func map(_ transform: (LoweredType) -> LoweredType) -> Binding {
        switch self {
        case let .fixed(type):
            return .fixed(transform(type))

        case let .declared(type):
            return .declared(transform(type))

        case let .assigned(type):
            return .assigned(transform(type))
        }
    }

    // MARK: - Private
}
