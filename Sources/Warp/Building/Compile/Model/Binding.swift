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
// every write, and one that did not holds what its last write put in it until
// a closure or a call takes it.
//
// How the name is held says the type written for what it holds, where one
// was, which is what a call of the value the name holds leans on. A type the
// build worked out is a reading and declares nothing.
//
// `Statement.Binding` is what a statement does to its name; this is what the
// name stands as afterwards.
struct Binding: Equatable, Sendable {
    // How a write meets the name, and what a slot declared it holds.
    enum Holding: Equatable, Sendable {
        // No write lands on it. A parameter, and a fixed name that declared
        // its type or whose value came from where one is written, hold what
        // was written there.
        case fixed(declared: LoweredType?)

        // A box every write is held to the type a slot declared: a variable
        // that wrote one, a parameter handed in place, and a module variable
        // that declared one.
        case declared(LoweredType)

        // A box every write is held to a type it read as, which no slot
        // declared: a module variable that wrote no type, held to what its
        // start settled as, and a variable a closure captured or a call
        // handed in place, held to what it read as there.
        case held(LoweredType)

        // A box every write retypes.
        case assigned
    }

    // MARK: - Property
    let holding: Holding

    // What the name reads as.
    let type: LoweredType

    // The type written for what the name holds, or nil where none was.
    var declaredType: LoweredType? {
        switch holding {
        case let .fixed(declared):
            return declared

        case let .declared(declared):
            return declared

        case .held, .assigned:
            return nil
        }
    }

    // The type every write to the name is held to, or nil where a write
    // retypes it or none lands.
    var heldType: LoweredType? {
        switch holding {
        case let .declared(type), let .held(type):
            return type

        case .fixed, .assigned:
            return nil
        }
    }

    // The type a box is held to once a closure or a call takes it: the one
    // its writes are already held to, else what it reads as. Nil for a name
    // no write lands on, which nothing takes.
    var takenType: LoweredType? {
        guard isBox else { return nil }

        return heldType ?? type
    }

    // Whether a write may land on the name at all.
    var isBox: Bool {
        if case .fixed = holding { return false }

        return true
    }

    // MARK: - Initializer
    // A name holds what it was given as a name holds it: a literal whole
    // number written to it is an Int from here on.
    init(_ holding: Holding, _ type: LoweredType) {
        self.holding = holding
        self.type = type.asHeld
    }

    // A parameter as the body holds it: one handed in place is the caller's
    // box, held to its type, and any other is a fixed name. Either way its
    // slot declared it.
    init(parameter declared: LoweredType) {
        switch declared {
        case let .inout(inner):
            self.init(.declared(inner.slotUnwrapped), inner.slotUnwrapped)

        case .any, .never, .null, .bool, .int, .wholeLiteral, .double, .string,
            .array, .dictionary, .struct, .procedure, .variable, .nullable,
            .named, .parameter, .composition:
            self.init(.fixed(declared: declared), declared)
        }
    }

    // MARK: - Public
    // The same name held the same way, reading as what the transform makes
    // of what it read as.
    func map(_ transform: (LoweredType) -> LoweredType) -> Binding {
        Binding(holding, transform(type))
    }

    // The same name once a closure or a call that holds it to `held` takes
    // it: a box every write retyped is held to that from there, still
    // reading as it did, and every other holding already says what a write
    // is held to.
    func taken(to held: LoweredType) -> Binding {
        guard case .assigned = holding else { return self }

        return Binding(.held(held), type)
    }

    // MARK: - Private
}
