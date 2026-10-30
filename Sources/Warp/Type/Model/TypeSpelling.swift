//
//  TypeSpelling.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

// The names the language gives the types it names, and the words a type's
// spelling writes in front of one, each written once. A document spells one
// of these types by its name, a claim about one is keyed by it, and a value
// is an instance of the one its kind is, so every table deciding one of
// those questions reads the name from here and no two of them can come to
// spell one type two ways.
public enum TypeSpelling {
    public static let any: Name = "Any"
    public static let never: Name = "Never"
    public static let null: Name = "Null"
    public static let bool: Name = "Bool"
    public static let int: Name = "Int"
    public static let double: Name = "Double"
    public static let string: Name = "String"
    public static let array: Name = "Array"
    public static let dictionary: Name = "Dictionary"
    public static let optional: Name = "Optional"
    public static let procedure: Name = "Procedure"

    // The type conforming to a contract, written in that contract's procedures.
    public static let selfType: Name = "Self"

    // The words a type's spelling writes in front of a type: a type
    // parameter, a procedure's constness and isolation, and a slot's marks.
    public static let some: Name = "some"
    public static let const: Name = "const"
    public static let isolated: Name = "isolated"
    public static let `inout`: Name = "inout"
    public static let variable: Name = "var"

    // The word a procedure type writes before what it may fail with.
    public static let `throws`: Name = "throws"

    // What the language declares itself: the contract a dictionary's key conforms to,
    // the failure a catch binds, the round a loop binds, and the marker an
    // Optional's some holds a none in.
    public static let hashable: Name = "Hashable"
    public static let failure: Name = "Failure"
    public static let round: Name = "Round"
    public static let marker: Name = "Some"

    // What a claim about `Array` or `Dictionary` reads an element, and a
    // dictionary's key, as: a type parameter nothing fills, spelled with a dot,
    // which no document's `some` writes, so it is no parameter a declaration
    // names.
    static let selfElement: Name = "Self.Element"
    static let selfKey: Name = "Self.Key"

    // The same parameters as a bare head of a list or a dictionary applies the type
    // to, which a claim reads as the two above.
    static let element: Name = "Element"
    static let key: Name = "Key"

    // What the language's claim about every Optional applies it to: its
    // payload's type.
    static let wrapped: Name = "Wrapped"
}
