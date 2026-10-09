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

    // A procedure's signature, or a closure's.
    case signature

    // The signature of a contract's procedure.
    case contract

    // The type a value is said to have: what a name, a module variable
    // included, says it holds, and what a cast reads a value as.
    case value

    // MARK: - Property
    // Whether `some T` may stand here: a call fills it.
    var takesTypeParameter: Bool {
        switch self {
        case .signature, .contract: true
        case .declaration, .value: false
        }
    }

    // Whether `Self` may stand here: a claim says what answers it.
    var takesSelf: Bool {
        switch self {
        case .contract: true
        case .declaration, .signature, .value: false
        }
    }

    // Whether a record's field may be written `var`: a path writes through a
    // declared type's field.
    var takesWritableFields: Bool {
        switch self {
        case .declaration: true
        case .signature, .contract, .value: false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
