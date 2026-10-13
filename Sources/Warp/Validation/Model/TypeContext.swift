//
//  TypeContext.swift
//  Warp
//
//  Created by JSilver on 10/9/26.
//

import Foundation

// Where a type is written, which is what decides the words that may stand in
// it. Each is a fact of the text: a type parameter lives where a call or a
// mention fills it, and `Self` where a contract is answered.
enum TypeContext: Sendable {
    // A procedure's signature, which declares the type parameters it names.
    case signature

    // A closure's signature, inside a procedure declaring these type
    // parameters. Its `some T` is the `T` of that procedure.
    case closure(of: Set<Name>)

    // The signature of a contract's procedure.
    case contract

    // A field of a declared struct taking these type parameters, which a
    // mention of the struct fills.
    case `struct`(declaring: Set<Name>)

    // What a document gives something to: a type, and what it is applied to,
    // whose `some T` is the head's own.
    case head

    // The type a value is said to have: what a name, a module variable
    // included, says it holds, what a cast reads a value as, and what a
    // declared type's field holds or an alias stands for.
    case value

    // MARK: - Property
    // Whether `Self` may stand here: a claim says what answers it.
    var takesSelf: Bool {
        switch self {
        case .contract: true
        case .signature, .closure, .struct, .head, .value: false
        }
    }

    // Whether a signature written here declares the type parameters it
    // names, which a closure's does not: its `some T` is the procedure's
    // around it.
    var declaresTypeParameters: Bool {
        switch self {
        case .signature, .contract: true
        case .closure, .struct, .head, .value: false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether `some T` may stand here: a call or a mention fills it.
    func takes(typeParameter name: Name) -> Bool {
        switch self {
        case .signature, .contract, .head: true
        case let .closure(declared), let .struct(declared): declared.contains(name)
        case .value: false
        }
    }

    // MARK: - Private
}
