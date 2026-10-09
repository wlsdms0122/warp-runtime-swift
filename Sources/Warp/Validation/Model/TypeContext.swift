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
// through a field.
enum TypeContext: Sendable {
    // A type declared in `types`, or what a name says it holds.
    case declaration

    // A procedure's signature, or a closure's.
    case signature

    // The signature of a contract's procedure.
    case contract

    // The type a cast reads a value as.
    case cast

    // MARK: - Property
    // Whether `some T` may stand here: a call fills it.
    var takesTypeParameter: Bool {
        switch self {
        case .signature, .contract: true
        case .declaration, .cast: false
        }
    }

    // Whether `Self` may stand here: a claim says what answers it.
    var takesSelf: Bool {
        switch self {
        case .contract: true
        case .declaration, .signature, .cast: false
        }
    }

    // Whether a record's field may be written `var`: a path writes through
    // what a declaration holds.
    var takesWritableFields: Bool {
        switch self {
        case .declaration: true
        case .signature, .contract, .cast: false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
