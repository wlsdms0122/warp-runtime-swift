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

    // A type a document gives a type under a name, whose `some T` is a type
    // parameter of the head it is given under, or of the struct where its
    // declaration gives it: these.
    case typeMember(declaring: Set<Name>)

    // The type a value is said to have: what a name, a module variable
    // included, says it holds, what a cast reads a value as, and what a
    // declared type's field holds or an alias stands for.
    case value

    // MARK: - Property
    // Whether `Self` may stand here: a claim says what answers it.
    var takesSelf: Bool {
        switch self {
        case .contract: true
        case .signature, .closure, .struct, .head, .typeMember, .value: false
        }
    }

    // Whether a signature written here declares the type parameters it
    // names, which a closure's does not: its `some T` is the procedure's
    // around it.
    var declaresTypeParameters: Bool {
        switch self {
        case .signature, .contract: true
        case .closure, .struct, .head, .typeMember, .value: false
        }
    }

    // Whether an associated type, `some T.Item`, may stand here: what fills
    // `T` decides it. A struct's field writes none, since a value carries no
    // type's arguments and a door reads what fills a struct's parameters off
    // its fields, which `T.Item` says nothing of. A head writes none, since it
    // is a type a value is an instance of.
    var takesAssociatedType: Bool {
        switch self {
        case .signature, .closure, .contract, .typeMember: true
        case .struct, .head, .value: false
        }
    }

    // Why an associated type does not stand here.
    var refusesAssociatedType: String {
        switch self {
        case .struct:
            "a struct's field writes no associated type of a type parameter. A value carries no type's"
                + " arguments, so what fills a struct's parameters is read off its fields, and an associated"
                + " type says nothing of its parameter"

        case .head:
            "a head writes no associated type of a type parameter. A head is a type a value is an instance of"

        case .signature, .closure, .contract, .typeMember, .value:
            "nothing here is filled by a call. An associated type stands on a type parameter of a signature"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether `some T` may stand here: a call or a mention fills it.
    func takes(typeParameter name: Name) -> Bool {
        switch self {
        case .signature, .contract, .head: true
        case let .closure(declared), let .struct(declared), let .typeMember(declared): declared.contains(name)
        case .value: false
        }
    }

    // MARK: - Private
}
