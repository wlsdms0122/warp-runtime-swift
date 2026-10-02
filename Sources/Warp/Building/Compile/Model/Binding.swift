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
// Beside what the name reads as stands the type a slot declared it holds,
// where one did, which is what a call of the value the name holds leans on.
// A type the build worked out is a reading and declares nothing.
//
// `Statement.Binding` is what a statement does to its name; this is what the
// name stands as afterwards.
struct Binding: Equatable, Sendable {
    // How a write meets the name.
    enum Holding: Equatable, Sendable {
        // No write lands on it.
        case fixed

        // Every write is held to its type: a variable that declared one, a
        // parameter handed in place, and a module variable, which holds the
        // type it started as where it declared none.
        case declared

        // Every write retypes it.
        case assigned
    }

    // MARK: - Property
    let holding: Holding

    // What the name reads as.
    let type: LoweredType

    // The type a slot declared the name holds, or nil where none did.
    let declaredType: LoweredType?

    // Whether a write may land on the name at all.
    var isBox: Bool {
        holding != .fixed
    }

    // MARK: - Initializer
    init(_ holding: Holding, _ type: LoweredType, declaredType: LoweredType? = nil) {
        self.holding = holding
        self.type = type
        self.declaredType = declaredType
    }

    // A parameter as the body holds it: one handed in place is the caller's
    // box, held to its type, and any other is a fixed name. Either way its
    // slot declared it.
    init(parameter declared: LoweredType) {
        switch declared {
        case let .inout(inner):
            self.init(.declared, inner.slotUnwrapped, declaredType: inner.slotUnwrapped)

        case .any, .never, .null, .bool, .int, .double, .string,
            .ranged, .array, .dictionary, .record, .procedure, .variable, .nullable,
            .named, .parameter, .composition, .projection, .undeclared:
            self.init(.fixed, declared, declaredType: declared)
        }
    }

    // MARK: - Public
    // The same name held the same way, reading as what the transform makes
    // of what it read as.
    func map(_ transform: (LoweredType) -> LoweredType) -> Binding {
        Binding(holding, transform(type), declaredType: declaredType)
    }

    // MARK: - Private
}
