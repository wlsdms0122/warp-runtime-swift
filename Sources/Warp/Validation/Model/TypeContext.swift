//
//  TypeContext.swift
//  Warp
//
//  Created by JSilver on 10/9/26.
//

import Foundation

// Where a type is written, which is what decides the words that may stand in
// it. Each is a fact of the text: a type parameter lives where a call fills
// it, `Self` where a contract is answered, and `var` where a path writes
// through a field of a declared type.
enum TypeContext: Sendable {
    // A type declared in `types`.
    case declaration

    // A procedure's signature, which declares the type parameters it names.
    case signature

    // A closure's signature, inside a procedure declaring these type
    // parameters. Its `some T` is the `T` of that procedure.
    case closure(of: Set<Name>)

    // The signature of a contract's procedure.
    case contract

    // The type a value is said to have: what a name, a module variable
    // included, says it holds, and what a cast reads a value as.
    case value

    // MARK: - Property
    // Whether `Self` may stand here: a claim says what answers it.
    var takesSelf: Bool {
        switch self {
        case .contract: true
        case .declaration, .signature, .closure, .value: false
        }
    }

    // Whether a signature written here declares the type parameters it
    // names, which a closure's does not: its `some T` is the procedure's
    // around it.
    var declaresTypeParameters: Bool {
        switch self {
        case .signature, .contract: true
        case .declaration, .closure, .value: false
        }
    }

    // Whether a record's field may be written `var`: a path writes through a
    // declared type's field.
    var takesWritableFields: Bool {
        switch self {
        case .declaration: true
        case .signature, .closure, .contract, .value: false
        }
    }

    // Where a type written inside one written here stands. A declared type's
    // own fields are the ones a path writes through by `var`; a record
    // inside one is an inline record, whose fields are written through as
    // they are.
    var nested: TypeContext {
        switch self {
        case .declaration: .value
        case .signature, .closure, .contract, .value: self
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether `some T` may stand here: a call fills it.
    func takes(typeParameter name: Name) -> Bool {
        switch self {
        case .signature, .contract: true
        case let .closure(declared): declared.contains(name)
        case .declaration, .value: false
        }
    }

    // MARK: - Private
}
