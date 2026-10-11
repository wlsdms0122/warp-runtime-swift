//
//  ObjectLayout.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation

// How an object is laid out as a value: the format under *objects* in the
// specification, the keys its record carries, and the tag each kind of every
// part is written with. The writer and the reader both spell the layout
// through these, so it is said once.
enum ObjectLayout {
    // The keys of the record. The format is said under `object`, which is also
    // what tells an object from a document at the door: a document says `warp`.
    enum Key: String, CaseIterable {
        case object
        case document
        case dependencies
        case types
        case contracts
        case claims
        case leaned
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
        case record
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
        case record
        case procedure
        case variable
        case `inout`
        case nullable
        case named
        case parameter
        case composition
        case projection
        case selfType
    }

    enum SegmentTag: Int {
        case key
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

    // A step of a place.
    enum PlaceStepTag: Int {
        case key
        case part
        case construct
        case index
        case statement
        case landmark
    }

    // A part of the program a place steps into.
    enum PartTag: Int {
        case procedures
        case constants
        case variables
        case types
        case contracts
        case satisfies
        case imports
        case parameters
        case returns
        case body
        case result
        case subject
        case callee
        case arguments
        case closure
        case condition
        case then
        case otherwise
        case rescue
        case fields
        case bounds
        case entries
    }

    enum ConditionHolderTag: Int {
        case conditional
        case loop
    }

    enum ConstructTag: Int {
        case literal
        case reference
        case array
        case record
        case closure
        case cast
        case block
        case conditional
        case loop
        case attempt
        case call
        case leave
        case dictionary
    }

    enum ReachTag: Int {
        case procedure
        case construct
        case round
    }

    // A type as a body stands on it.
    enum LoweredTypeTag: Int {
        case any
        case never
        case null
        case bool
        case int
        case double
        case string
        case array
        case dictionary
        case record
        case procedure
        case variable
        case `inout`
        case nullable
        case named
        case parameter
        case composition
        case projection
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
        case key
        case index
        case at
    }

    enum OperationTag: Int {
        case literal
        case local
        case array
        case record
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

    // Every key an object carries, which a reading holds a record to before it
    // reads any.
    static let keys = Set(Key.allCases.map(\.name))
}
