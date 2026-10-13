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

    // A value: its kind first, then what the kind holds.
    enum ValueTag: Int {
        case null
        case bool
        case int
        case double
        case string
        case bytes
        case array
        case `struct`
        case closure
        case dictionary
    }

    // The declaration that wrote a closure.
    enum DeclarationTag: Int {
        case procedure
        case binding
    }

    // A type as a document writes it.
    enum TypeTag: Int {
        case any
        case never
        case null
        case bool
        case int
        case double
        case string
        case array
        case dictionary
        case `struct`
        case procedure
        case variable
        case `inout`
        case nullable
        case named
        case parameter
        case composition
        case projection
        case selfType
        case member
    }

    enum SegmentTag: Int {
        case name
        case index
        case indexRef
    }

    enum AccessTag: Int {
        case `private`
        case `internal`
        case `public`
    }

    enum ConstnessTag: Int {
        case unstated
        case const
    }

    enum IsolationTag: Int {
        case unstated
        case isolated
    }

    enum FailingTag: Int {
        case unstated
        case these
    }

    enum ReachTag: Int {
        case procedure
        case construct
        case round
    }

    // A type as a body stands on it. Each tag is the number the page gives
    // it, written out, so a kind leaving takes its number with it and moves
    // no other.
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
        case projection = 17
    }

    enum ImplementationTag: Int {
        case body
        case native
    }

    enum BindingTag: Int {
        case bind
        case declare
        case assign
    }

    // A step of an address.
    enum StepTag: Int {
        case field
        case name
        case index
        case at
    }

    enum OperationTag: Int {
        case literal
        case local
        case array
        case `struct`
        case closure
        case apply
        case cast
        case block
        case conditional
        case loop
        case attempt
        case call
        case dispatch
        case leave
        case dictionary
    }

    enum ArgumentTag: Int {
        case value
        case reference
    }

    // The format, which moves when the layout moves and for no other reason.
    // What an object holds is the language's, so which implementation wrote
    // one is not written.
    static let format = 1

    // Every key an object carries, which a reading holds a map to before it
    // reads any.
    static let keys = Set(Key.allCases.map(\.name))
}
