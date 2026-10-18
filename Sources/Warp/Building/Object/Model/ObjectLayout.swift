//
//  ObjectLayout.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation

// How an object is laid out as a value: the format under *objects* in the
// specification, the keys its map carries, and the tag each kind of every
// part is written with. The writer and the reader both spell the layout
// through these, so it is said once.
enum ObjectLayout {
    // The keys of the map. The format is said under `object`, which is also
    // what tells an object from a document at the door: a document says `warp`.
    enum Key: String, CaseIterable {
        case object
        case document
        case dependencies
        case types
        case contracts
        case claims
        case members
        case typeMembers
        case importedClaims
        case rows
        case lifted
        case answers
        case numbering
        case typeNumbering
        case variables
        case constants

        // MARK: - Property
        var name: Name { Name(normal: rawValue) }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // Every tag below is the number the page gives it, written out, so a kind
    // leaving takes its number with it and moves no other.
    //
    // A value: its kind first, then what the kind holds.
    enum ValueTag: Int {
        case null = 0
        case bool = 1
        case int = 2
        case double = 3
        case string = 4
        case bytes = 5
        case array = 6
        case `struct` = 7
        case closure = 8
        case dictionary = 9
    }

    // The declaration that wrote a closure.
    enum DeclarationTag: Int {
        case procedure = 0
        case binding = 1
    }

    // A type as a document writes it.
    enum TypeTag: Int {
        case any = 0
        case never = 1
        case null = 2
        case bool = 3
        case int = 4
        case double = 5
        case string = 6
        case array = 7
        case dictionary = 8
        case `struct` = 9
        case procedure = 10
        case variable = 11
        case `inout` = 12
        case nullable = 13
        case named = 14
        case parameter = 15
        case composition = 16
        case selfType = 18
        case associatedType = 19
    }

    enum AccessTag: Int {
        case `private` = 0
        case `internal` = 1
        case `public` = 2
    }

    enum ConstnessTag: Int {
        case unstated = 0
        case const = 1
    }

    enum IsolationTag: Int {
        case unstated = 0
        case isolated = 1
    }

    enum FailingTag: Int {
        case anything = 0
        case these = 1
    }

    enum ReachTag: Int {
        case procedure = 0
        case construct = 1
        case round = 2
    }

    // A type as a body stands on it.
    enum LoweredTypeTag: Int {
        case any = 0
        case never = 1
        case null = 2
        case bool = 3
        case int = 4
        case double = 5
        case string = 6
        case array = 7
        case dictionary = 8
        case procedure = 10
        case variable = 11
        case `inout` = 12
        case nullable = 13
        case named = 14
        case parameter = 15
        case composition = 16
    }

    enum ImplementationTag: Int {
        case body = 0
        case native = 1
    }

    enum BindingTag: Int {
        case bind = 0
        case declare = 1
        case assign = 2
    }

    // A step of an address.
    enum StepTag: Int {
        case field = 0
        case name = 1
        case index = 2
        case at = 3
    }

    enum OperationTag: Int {
        case literal = 0
        case local = 1
        case array = 2
        case `struct` = 3
        case closure = 4
        case apply = 5
        case cast = 6
        case conditional = 8
        case loop = 9
        case attempt = 10
        case call = 11
        case dispatch = 12
        case leave = 13
        case dictionary = 14
    }

    enum ArgumentTag: Int {
        case value = 0
        case reference = 1
    }

    // The format, which moves when the layout moves and for no other reason.
    // What an object holds is the language's, so which implementation wrote
    // one is not written.
    static let format = 1

    // Every key an object carries, which a reading holds a map to before it
    // reads any.
    static let keys = Set(Key.allCases.map(\.name))
}
