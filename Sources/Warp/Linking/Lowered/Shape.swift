//
//  Shape.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A type as the run reads it: the declaration's type with every name the
// link resolved written in as a row of the shape table. What a document
// spells stays `TypeExpression`; this is the link's product, the way `Code`
// is the product of an `Expression`. Every judgment over a value or a
// reading lives here, and the document's type reaches it by lowering.
indirect enum Shape: Sendable {
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
    case array(Shape)
    case object(Shape)

    // Fields in name order, as `Name`'s `<` orders them.
    case record([(name: Name, shape: Shape)])

    // What a slot asks of a procedure value: the parameters it may be called
    // with, in position order, and what it must answer. Nil where nothing
    // was declared. Purity and isolation are the slot's requirements.
    case procedure(
        parameters: [(name: Name, shape: Shape)]?,
        returns: Shape?,
        purity: Purity,
        isolation: Isolation
    )

    case variable(Shape)
    case `inout`(Shape)
    case nullable(Shape)

    // A declared type, by its row in the table.
    case named(Int)

    // A type parameter the call fills. The label is the spelling a refusal
    // shows; the constraint is the row of the membership it is bounded by.
    case parameter(label: Name, constraint: Int?)

    // A name the table does not answer: nothing declares it, or it names
    // itself. Nothing can be said about it, so every judgment over readings
    // lets it pass, and the value judge refuses it in the refusal's words.
    // A table a host built by hand answers instead of failing to lower, and
    // only the judgments that reach the name are touched by it. The link
    // refuses such a name as it lowers the table, so a run never meets one.
    case undeclared(label: Name, refusal: String)

    // MARK: - Property
    var inoutUnwrapped: Shape {
        if case let .inout(inner) = self { return inner }

        return self
    }

    // What a slot holds, through the two marks that say how it is held
    // rather than what it is.
    var slotUnwrapped: Shape {
        switch self {
        case let .variable(inner), let .inout(inner):
            return inner.slotUnwrapped

        default:
            return self
        }
    }

    // The row this stands on, through `?`, `var` and `inout`, which hold no
    // value of their own. Nil for a shape that names no row. What follows a
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
    var unrefined: Shape {
        switch self {
        case let .ranged(refinement):
            return refinement.shape

        case .bytes:
            return .array(.byteElement)

        default:
            return self
        }
    }

    // Whether what this stands for is settled at the call.
    var decidedAtCall: Bool {
        if case .parameter = self { return true }

        return false
    }

    // Whether this shape proves nothing about the value it holds.
    var provesNothing: Bool {
        self == .any || self == .never || decidedAtCall
    }

    // Whether this names one of the kinds a value simply is.
    var isDecidedKind: Bool {
        switch self {
        case .bool, .int, .double, .string, .null, .number, .array, .object, .record:
            return true

        default:
            return false
        }
    }

    // What one element of bytes is: the range `std` names `byte`.
    static let byteElement = Shape.ranged(.whole(from: 0, to: .through(255)))

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

extension Shape: Equatable {
    static func == (lhs: Shape, rhs: Shape) -> Bool {
        switch (lhs, rhs) {
        case (.any, .any), (.never, .never), (.null, .null), (.bool, .bool), (.int, .int),
            (.double, .double), (.string, .string), (.bytes, .bytes), (.number, .number):
            return true

        case let (.ranged(mine), .ranged(theirs)):
            return mine == theirs

        case let (.array(mine), .array(theirs)), let (.object(mine), .object(theirs)),
            let (.variable(mine), .variable(theirs)), let (.inout(mine), .inout(theirs)),
            let (.nullable(mine), .nullable(theirs)):
            return mine == theirs

        case let (.record(mine), .record(theirs)):
            return Shape.same(mine, theirs)

        case let (.procedure(mine, myAnswer, myPurity, myIsolation),
                  .procedure(theirs, theirAnswer, theirPurity, theirIsolation)):
            guard myPurity == theirPurity, myIsolation == theirIsolation, myAnswer == theirAnswer else {
                return false
            }

            switch (mine, theirs) {
            case (nil, nil):
                return true

            case let (mine?, theirs?):
                return Shape.same(mine, theirs)

            default:
                return false
            }

        case let (.named(mine), .named(theirs)):
            return mine == theirs

        case let (.parameter(myLabel, mine), .parameter(theirLabel, theirs)):
            return myLabel == theirLabel && mine == theirs

        case let (.undeclared(mine, _), .undeclared(theirs, _)):
            return mine == theirs

        default:
            return false
        }
    }

    private static func same(_ mine: [(name: Name, shape: Shape)], _ theirs: [(name: Name, shape: Shape)]) -> Bool {
        mine.count == theirs.count
            && zip(mine, theirs).allSatisfy { one, other in
                one.name == other.name && one.shape == other.shape
            }
    }
}
