//
//  LoweredType.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A type as the run reads it: the declaration's type with every name the
// link resolved written in as a row of the lowered type table. What a document
// spells stays `TypeExpression`; this is the link's product, the way `Operation`
// is the product of an `Expression`. Every judgment over a value or a
// reading lives here, and the document's type reaches it by lowering.
indirect enum LoweredType: Sendable {
    case any
    case never
    case null
    case bool
    case int
    case double
    case string
    case bytes
    case number
    case ranged(TypeExpression.Refinement)
    case array(LoweredType)
    case dictionary(LoweredType)

    case record(LoweredRecord)

    // What a slot asks of a procedure value: the parameters it may be called
    // with, in position order, and what it must answer. Nil where nothing
    // was declared. Constness and isolation are the slot's requirements.
    case procedure(
        parameters: [LoweredParameter]?,
        returns: LoweredType?,
        constness: Constness,
        isolation: Isolation
    )

    case variable(LoweredType)
    case `inout`(LoweredType)
    case nullable(LoweredType)

    // A declared type, by its row in the table.
    case named(Int)

    // A type parameter the call fills. The label is the spelling a refusal
    // shows; the bound is what the signature held it to.
    case parameter(label: Name, bound: Bound?)

    // What a type parameter is held to. Two, because the two are answered
    // differently: a membership lists types and the table lowered them into
    // rows, a contract lists procedures and what answers it is a type's own name.
    enum Bound: Sendable, Equatable {
        case membership(Int)
        case contract(Name)
    }

    // The type a walk reached by taking a path through one a call decides.
    // The root is the type parameter's spelling and the path is what was
    // walked from it, so two walks landing on one field land on one type.
    // Nothing is proven about what it holds, so every judgment answers it the
    // way it answers `any`; it stands apart for the walk's own naming.
    case reading(of: Name, path: [PathSegment])

    // A declared membership standing as a type, by its row: a value of one of
    // the types it admits. What a slot holds here is decided, and which of the
    // members it is only a cast tells apart.
    case member(Int)

    // A name the table does not answer: nothing declares it, or it names
    // itself. Nothing can be said about it, so every judgment over readings
    // lets it pass, and the value judge refuses it in the refusal's procedures.
    // A table a host built by hand answers instead of failing to lower, and
    // only the judgments that reach the name are touched by it. The link
    // refuses such a name as it lowers the table, so a run never meets one.
    case undeclared(label: String, refusal: String)

    // MARK: - Property
    // What a field a declaration wrote `var` holds. The mark is a fact about
    // the field, and what is read out of it is the type inside.
    //
    // No `default` on either below: a mark nobody thought about must be a
    // compile error here rather than an answer of "no mark".
    var fieldUnwrapped: LoweredType {
        switch self {
        case let .variable(inner):
            return inner

        case .any, .never, .null, .bool, .int, .double, .string, .bytes, .number,
            .ranged, .array, .dictionary, .record, .procedure, .inout, .nullable,
            .named, .parameter, .reading, .member, .undeclared:
            return self
        }
    }

    // Whether a slot holding this may be written through.
    var isVariable: Bool {
        if case .variable = self { return true }

        return false
    }

    // What a slot holds, through the two marks that say how it is held
    // rather than what it is.
    var slotUnwrapped: LoweredType {
        switch self {
        case let .variable(inner), let .inout(inner):
            return inner.slotUnwrapped

        case .any, .never, .null, .bool, .int, .double, .string, .bytes, .number,
            .ranged, .array, .dictionary, .record, .procedure, .nullable,
            .named, .parameter, .reading, .member, .undeclared:
            return self
        }
    }

    // The row this stands on, through `?`, `var` and `inout`, which hold no
    // value of their own. Nil for a type that names no row. What follows a
    // chain of names follows this, so a name reached under a wrapper is a
    // link of the chain and not its end.
    var row: Int? {
        switch self {
        case let .named(row):
            return row

        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.row

        default:
            return nil
        }
    }

    // The spelling with its conditions dropped: a range is its kind, and
    // bytes are `array<byte>` compacted.
    var unrefined: LoweredType {
        switch self {
        case let .ranged(refinement):
            return refinement.lowered

        case .bytes:
            return .array(.byteElement)

        default:
            return self
        }
    }

    // Whether what this stands for is settled at the call.
    var decidedAtCall: Bool {
        switch self {
        case .parameter, .reading:
            return true

        default:
            return false
        }
    }

    // What a walk through this type reaches by taking those segments. Nil
    // where this is not a type a call decides, which is where a walk has a
    // type to read the segments against and no need for one of these.
    //
    // Asked of the type rather than assembled at the walk, because the root
    // is the type's own fact: a parameter roots a reading at itself, and a
    // reading already rooted extends the path it carries.
    //
    // The marks come off on the way in: what a mark says is expected of the
    // value, and where the walk landed is the same field either way.
    func reaching(_ path: [PathSegment]) -> LoweredType? {
        switch self {
        case let .parameter(name, _):
            return .reading(of: name, path: path.map(\.unmarked))

        case let .reading(of, walked):
            return .reading(of: of, path: walked + path.map(\.unmarked))

        default:
            return nil
        }
    }

    // Where a field stands in this type, and what stands there. Nil where
    // the link did not prove a layout: a dictionary, a value that arrived
    // through `any`, or a type a call still decides. A box is read through,
    // since a path reads what the box holds.
    //
    // The place is the value's, not only the type's. A value settling to a
    // record type is built on that type's layout, so a field the link
    // proved stands where the layout puts it.
    func place(of field: Name, in table: LoweredTypeTable) -> (position: Int, type: LoweredType)? {
        switch self {
        case let .record(held):
            guard let position = held.layout.position(of: field) else { return nil }

            return (position, held.fields[position])

        case let .named(row):
            return table.loweredTypes[row].place(of: field, in: table)

        case let .variable(inner), let .inout(inner):
            return inner.place(of: field, in: table)

        default:
            return nil
        }
    }

    // What an element of this stands as, for a walk taking an index. Nil
    // where the link proved no element type.
    func element(in table: LoweredTypeTable) -> LoweredType? {
        switch self {
        case let .array(element):
            return element

        // A dictionary's names are data, so a key the run computes reads an
        // entry the way an index reads an element.
        case let .dictionary(entry):
            return entry

        case .bytes:
            return .byteElement

        case let .named(row):
            return table.loweredTypes[row].element(in: table)

        case let .variable(inner), let .inout(inner):
            return inner.element(in: table)

        default:
            return nil
        }
    }

    // Whether two procedure types declare the same slots and the same answer.
    // What each requires of the value is beside that, so a join may keep the
    // slots while reading the two requirements together.
    func sameProcedure(as other: LoweredType) -> Bool {
        guard
            case let .procedure(mine, myAnswer, _, _) = self,
            case let .procedure(theirs, theirAnswer, _, _) = other
        else {
            return false
        }

        guard myAnswer == theirAnswer else { return false }

        switch (mine, theirs) {
        case (nil, nil):
            return true

        case let (mine?, theirs?):
            return mine == theirs

        default:
            return false
        }
    }

    // What a judgment sees. A reading says a path was taken through a type
    // the call decides, which proves nothing about what it holds, and that is
    // what `any` says.
    var judged: LoweredType {
        if case .reading = self { return .any }

        return self
    }

    // Whether this type proves nothing about the value it holds.
    var provesNothing: Bool {
        self == .any || self == .never || decidedAtCall
    }

    // Whether this names one of the kinds a value simply is.
    var isDecidedKind: Bool {
        switch self {
        case .bool, .int, .double, .string, .null, .number, .array, .dictionary, .record:
            return true

        default:
            return false
        }
    }

    // What one element of bytes is: the range `std` names `byte`.
    static let byteElement = LoweredType.ranged(.whole(from: 0, to: .through(255)))

    // A record of these fields, laid out the way the link lays every record
    // out: by the order of the field spellings.
    static func record(_ fields: [Name: LoweredType]) -> LoweredType {
        let ordered = fields.sorted { left, right in left.key < right.key }

        return .record(
            LoweredRecord(
                layout: Layout(name: nil, ordered: ordered.map(\.key)),
                fields: ordered.map(\.value)
            )
        )
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

extension LoweredType: Equatable {
    static func == (lhs: LoweredType, rhs: LoweredType) -> Bool {
        switch (lhs, rhs) {
        case (.any, .any), (.never, .never), (.null, .null), (.bool, .bool), (.int, .int),
            (.double, .double), (.string, .string), (.bytes, .bytes), (.number, .number):
            return true

        case let (.ranged(mine), .ranged(theirs)):
            return mine == theirs

        case let (.array(mine), .array(theirs)), let (.dictionary(mine), .dictionary(theirs)),
            let (.variable(mine), .variable(theirs)), let (.inout(mine), .inout(theirs)),
            let (.nullable(mine), .nullable(theirs)):
            return mine == theirs

        case let (.record(mine), .record(theirs)):
            return mine == theirs

        case let (.procedure(_, _, myConstness, myIsolation),
                  .procedure(_, _, theirConstness, theirIsolation)):
            return myConstness == theirConstness
                && myIsolation == theirIsolation
                && lhs.sameProcedure(as: rhs)

        case let (.named(mine), .named(theirs)):
            return mine == theirs

        case let (.parameter(myLabel, mine), .parameter(theirLabel, theirs)):
            return myLabel == theirLabel && mine == theirs

        case let (.member(mine), .member(theirs)):
            return mine == theirs

        case let (.reading(myRoot, myPath), .reading(theirRoot, theirPath)):
            return myRoot == theirRoot && myPath == theirPath

        case let (.undeclared(mine, _), .undeclared(theirs, _)):
            return mine == theirs

        default:
            return false
        }
    }

}
