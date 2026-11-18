//
//  ValueRepresentable.swift
//  Warp
//

import Foundation

// A Swift type standing for a type of the language: the type a signature
// writes for it, the declaration of the name it writes, if any, and the way
// between its values and the language's.
public protocol ValueRepresentable {
    static var type: TypeExpression { get }

    // What the name `type` writes is declared as, by the module that lists
    // this type among the types it declares, so a type with a declaration
    // writes a named type.
    static var declaration: TypeDeclaration? { get }

    init(_ value: Value) throws

    var value: Value { get throws }
}

extension ValueRepresentable {
    public static var declaration: TypeDeclaration? { nil }

    // Inlined, so a conformance's reading calls no generic function and a
    // generic caller's `Self(value)` resolves to the conformance's own body.
    @inlinable
    static func refusal(of value: Value) -> ValueRefused {
        ValueRefused(reading: type, arrived: value)
    }
}
