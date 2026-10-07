//
//  TypeSpelling.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

// The names the language gives the types it names, each written once. A
// document spells one of these types by its name, a claim about one is keyed
// by it, and a value is an instance of the one its kind wears, so every table
// answering one of those questions reads the name from here and no two of
// them can come to spell one type two ways.
public enum TypeSpelling {
    // MARK: - Property
    public static let any: Name = "Any"
    public static let never: Name = "Never"
    public static let null: Name = "Null"
    public static let bool: Name = "Bool"
    public static let int: Name = "Int"
    public static let double: Name = "Double"
    public static let string: Name = "String"
    public static let array: Name = "Array"
    public static let dictionary: Name = "Dictionary"
    public static let procedure: Name = "Procedure"

    // The type answering a contract, written in that contract's procedures.
    public static let selfType: Name = "Self"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
