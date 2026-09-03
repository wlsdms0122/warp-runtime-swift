//
//  Shape+Accepting.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The reading judges: whether one shape may stand where another is
// declared, and whether some value could satisfy two shapes at once. The
// link asks them of readings; the run asks the first of a closure value
// that reached a procedure slot through `any`.
extension Shape {
    // Whether a value of `other` may stand where this is declared.
    // Structural, and one-directional: `any` on the left accepts anything
    // because nothing was declared, and `any` on the right is accepted by
    // anything because nothing is known.
    func accepts(_ other: Shape, in table: ShapeTable) -> Bool {
        accepts(other, in: table, assuming: [])
    }

    // The same question, carrying which pairs are already being asked. A
    // named type may reach itself through a shape, so comparing one
    // structurally walks back to the comparison it is inside, and a
    // recursive shape agrees with itself precisely when assuming it does
    // uncovers no disagreement. Only the two `named` doors record the pair.
    func accepts(_ other: Shape, in table: ShapeTable, assuming: [(Shape, Shape)]) -> Bool {
        // Two declared records under two names are two types, whatever their
        // shapes: a value settled under one name fits only that name.
        if
            case let .named(mine) = self,
            case let .named(theirs) = other,
            let myRecord = table.recordRows[mine],
            let theirRecord = table.recordRows[theirs],
            myRecord != theirRecord
        {
            return false
        }

        switch (self, other) {
        // What answers `never` never arrives, so it cannot be the value that
        // disagrees with a declaration. The other way round it fits nowhere.
        case (_, .never):
            return true

        // A type parameter accepts whatever fills it, and what fills it is
        // worked out at the call rather than here. In the other direction a
        // parameter stands for some type and this one is that type.
        case (.parameter, _), (_, .parameter):
            return true

        // `var` and `inout` are facts about a slot, and fitting is asked of
        // the inner type on either side.
        case let (.variable(inner), _), let (.inout(inner), _):
            return inner.accepts(other, in: table, assuming: assuming)

        case let (_, .variable(inner)), let (_, .inout(inner)):
            return accepts(inner, in: table, assuming: assuming)

        case (.any, _), (_, .any):
            return true

        case (.never, _):
            return false

        // A name nothing answers stands for no shape, so nothing fits it and
        // it fits nothing.
        case (.undeclared, _), (_, .undeclared):
            return false

        case let (.named(row), _):
            guard !assuming.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return table.shapes[row].accepts(other, in: table, assuming: assuming + [(self, other)])

        case let (_, .named(row)):
            guard !assuming.contains(where: { pair in pair.0 == self && pair.1 == other }) else { return true }

            return accepts(table.shapes[row], in: table, assuming: assuming + [(self, other)])

        // A nullable slot takes null, the declared half, and anything
        // nullable whose declared half it takes. What may be null does not
        // stand where null was never declared.
        case (.nullable, .null):
            return true

        case let (.nullable(mine), .nullable(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        case let (.nullable(mine), _):
            return mine.accepts(other, in: table, assuming: assuming)

        case let (.array(mine), .array(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        case let (.object(mine), .object(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        // A record is an object whose fields happen to be known: a record
        // whose every field is the entry shape is such a mapping. Not the
        // other way round, since an `object` promises nothing about which
        // fields exist.
        case let (.object(mine), .record(theirs)):
            return theirs.allSatisfy { _, field in mine.accepts(field, in: table, assuming: assuming) }

        // Width: what stands here must declare at least the fields this one
        // names, and may declare more.
        case let (.record(mine), .record(theirs)):
            return mine.allSatisfy { name, field in
                theirs.first { given in Name.same(given.name, name) }
                    .map { given in field.accepts(given.shape, in: table, assuming: assuming) } ?? false
            }

        case let (.procedure(required, wanted, wantedPurity, wantedIsolation),
                  .procedure(given, offered, offeredPurity, offeredIsolation)):
            // A slot asking for purity takes only what says it is pure, and
            // one asking for isolation only what says it is isolated, or
            // pure, since what runs nothing touches nothing.
            guard wantedPurity != .pure || offeredPurity == .pure else { return false }
            guard wantedIsolation != .isolated || offeredIsolation == .isolated || offeredPurity == .pure else {
                return false
            }

            // Nothing was said on one side or the other, so nothing is refused.
            guard let required, let given else { return true }

            // The directions are opposite on purpose: what is given must
            // accept everything that will be passed to it, and what is
            // required must accept everything it will get back. A parameter
            // the body leaves out is not a disagreement.
            for (name, shape) in required {
                guard let taken = given.first(where: { slot in Name.same(slot.name, name) }) else { continue }
                guard taken.shape.accepts(shape, in: table, assuming: assuming) else { return false }
            }

            return (wanted ?? .any).accepts(offered ?? .any, in: table, assuming: assuming)

        // Two ranges are the one meeting where both sides are the text's
        // fact: the kinds under them decide which way a value may widen, and
        // bounds that cannot overlap are provably apart.
        case let (.ranged(mine), .ranged(theirs)):
            return mine.shape.accepts(theirs.shape, in: table, assuming: assuming)
                && mine.overlaps(theirs)

        // A range against anything else is its kind against that: the bounds
        // speak where a value is settled.
        case let (.ranged(mine), _):
            return mine.shape.accepts(other, in: table, assuming: assuming)

        case let (_, .ranged(theirs)):
            return accepts(theirs.shape, in: table, assuming: assuming)

        // `bytes` and `array<byte>` are one type in two spellings, so each
        // side reads by its elements.
        case let (.array(mine), .bytes):
            return mine.accepts(.byteElement, in: table, assuming: assuming)

        case let (.bytes, .array(theirs)):
            return Shape.byteElement.accepts(theirs, in: table, assuming: assuming)

        // The one conversion the language has, the way that cannot lose
        // anything.
        case (.double, .int):
            return true

        case (.number, .int), (.number, .double):
            return true

        // A value known only this loosely fits a slot that takes everything
        // the looseness covers, and no slot that takes less.
        case (_, .number):
            return accepts(.int, in: table, assuming: assuming)
                && accepts(.double, in: table, assuming: assuming)

        default:
            return self == other
        }
    }

    // Whether some value could satisfy both shapes at once. Not `accepts`:
    // two records that name no field in common accept each other in neither
    // direction and are still both satisfied by a value carrying every
    // field. The bias is deliberate: a refusal is earned only where the
    // shapes provably disagree, and everything else is left to the run.
    func couldBothHold(_ other: Shape, in table: ShapeTable) -> Bool {
        couldBothHold(other, in: table, assuming: [])
    }

    // Names are peeled one layer at a time, with the rows already being
    // asked about remembered, because this walk is the one that recurses.
    private func couldBothHold(_ other: Shape, in table: ShapeTable, assuming: [Int]) -> Bool {
        if
            case let .named(mine) = self,
            case let .named(theirs) = other,
            let myRecord = table.recordRows[mine],
            let theirRecord = table.recordRows[theirs],
            myRecord != theirRecord
        {
            return false
        }

        if case let .named(row) = self {
            guard !assuming.contains(row) else { return true }

            return table.shapes[row].couldBothHold(other, in: table, assuming: assuming + [row])
        }

        if case let .named(row) = other {
            guard !assuming.contains(row) else { return true }

            return couldBothHold(table.shapes[row], in: table, assuming: assuming + [row])
        }

        if provesNothing || other.provesNothing { return true }

        // A name nothing answers is left to the run, the way a name not yet
        // resolved was.
        if case .undeclared = self { return true }
        if case .undeclared = other { return true }

        // Null is a value both hold, so one exists whatever else they say.
        if declaresNull(in: table), other.declaresNull(in: table) { return true }

        // Two ranges are asked of the judge that decides them, the way
        // `accepts` asks it: what is provably apart is refused here.
        if case let .ranged(mine) = self, case let .ranged(theirs) = other {
            return mine.shape.couldBothHold(theirs.shape, in: table, assuming: assuming)
                && mine.overlaps(theirs)
        }

        // Refinements and compact spellings are dropped first: whether a
        // value could be both is a question about kinds.
        switch (unrefined, other.unrefined) {
        case let (.nullable(inner), side), let (side, .nullable(inner)):
            return inner.couldBothHold(side, in: table, assuming: assuming)

        // What both name has to be able to hold at once; what only one names
        // is data the other lets ride through.
        case let (.record(mine), .record(theirs)):
            return mine.allSatisfy { name, field in
                theirs.first { given in Name.same(given.name, name) }
                    .map { given in field.couldBothHold(given.shape, in: table, assuming: assuming) } ?? true
            }

        // An object and a record are one runtime shape read two ways, so
        // every field the record names must be able to be an entry. A list
        // and a map are not asked about their elements: an empty one is of
        // every element type there is.
        case let (.object(entry), .record(fields)), let (.record(fields), .object(entry)):
            return fields.allSatisfy { _, field in field.couldBothHold(entry, in: table, assuming: assuming) }

        // Two decided kinds, which is where a value either is both or is
        // neither. Anything else this walk does not read into is the run's.
        case let (mine, theirs):
            guard mine.isDecidedKind, theirs.isDecidedKind else { return true }

            // Asked of the judge that will settle it, not of a second opinion
            // about what it would say. One witness per kind is enough here.
            return Shape.witnesses.contains { witness in
                mine.settles(witness, in: table) && theirs.settles(witness, in: table)
            }
        }
    }

    // One value of every kind a decided shape can hold, for asking the judge
    // rather than restating it.
    private static let witnesses: [Value] = [
        .null, .bool(false), .int(0), .double(0), .string(""),
        .array([]), .object([:]), .bytes([])
    ]

    private func settles(_ value: Value, in table: ShapeTable) -> Bool {
        (try? settling(value, at: "", in: table)) != nil
    }
}
