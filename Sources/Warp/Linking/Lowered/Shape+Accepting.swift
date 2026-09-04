//
//  Shape+Accepting.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The reading judges: whether one shape may stand where another is
// declared, whether two shapes are one shape, whether some value could
// satisfy two shapes at once, and whether a candidate spelling could ever be
// a value of a shape. The link
// asks them of readings; the run asks the first of a closure value that
// reached a procedure slot through `any`. A name the table does not answer
// passes every one of them: nothing is knowable about it here, and the
// value judge refuses it where a value arrives.
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

        // `var` is a fact about a slot, and fitting is asked of the inner
        // type.
        case let (.variable(inner), _):
            return inner.accepts(other, in: table, assuming: assuming)

        // A slot handed a variable in place is the two sides being one
        // shape, not one that fits the other. The body writes through the
        // caller's box and the caller reads back what the body wrote, so a
        // shape that merely fits would let the two disagree about what is
        // there — the body writing what its own declaration allows and the
        // caller reading what its own declaration promised.
        case let (.inout(inner), _):
            return inner.same(other.slotUnwrapped, in: table, assuming: assuming)

        case let (_, .variable(inner)), let (_, .inout(inner)):
            return accepts(inner, in: table, assuming: assuming)

        case (.any, _), (_, .any):
            return true

        case (.never, _):
            return false

        case (.undeclared, _), (_, .undeclared):
            return true

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

        case let (.dictionary(mine), .dictionary(theirs)):
            return mine.accepts(theirs, in: table, assuming: assuming)

        // A record is a dictionary whose fields happen to be known: a record
        // whose every field is the entry shape is such a mapping. Not the
        // other way round, since a `dictionary` promises nothing about which
        // fields exist.
        case let (.dictionary(mine), .record(theirs)):
            return theirs.fields.allSatisfy { field in mine.accepts(field, in: table, assuming: assuming) }

        // Width: what stands here must declare at least the fields this one
        // names, and may declare more.
        case let (.record(mine), .record(theirs)):
            return mine.named.allSatisfy { name, field in
                theirs[name].map { given in field.accepts(given, in: table, assuming: assuming) } ?? false
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

            // A body may declare fewer than the slot hands it, and may
            // declare more only where the name stands unfilled: a name
            // nothing hands it and a call must fill is one no call could.
            guard given.allSatisfy({ slot in
                !slot.mustBeGiven || required.contains { name, _, _ in name == slot.name }
            }) else {
                return false
            }

            // The directions are opposite on purpose: what is given must
            // accept everything that will be passed to it, and what is
            // required must accept everything it will get back.
            for (name, shape, _) in required {
                guard let taken = given.first(where: { slot in slot.name == name }) else { continue }
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
            return mine.named.allSatisfy { name, field in
                theirs[name].map { given in field.couldBothHold(given, in: table, assuming: assuming) } ?? true
            }

        // A dictionary and a record are one runtime shape read two ways, so
        // every field the record names must be able to be an entry. A list
        // and a map are not asked about their elements: an empty one is of
        // every element type there is.
        case let (.dictionary(entry), .record(held)), let (.record(held), .dictionary(entry)):
            return held.fields.allSatisfy { field in field.couldBothHold(entry, in: table, assuming: assuming) }

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

    // Whether a `oneOf` candidate could ever be a spelling of a value of this
    // shape. Candidates are written as the scalar spellings arguments are
    // compared under, so a shape with no scalar spelling spells none of
    // them, and a number is read by the spelling the boundary reads: `1e0`
    // is a fraction no fraction spells, so no call could ever match it.
    func spells(_ candidate: String, in table: ShapeTable) -> Bool {
        switch self {
        case .any, .string, .undeclared:
            return true

        case .int, .double, .number:
            return numeral(candidate, in: table) != nil

        // A candidate has to be a value the range itself would admit.
        case let .ranged(refinement):
            guard let value = refinement.shape.numeral(candidate, in: table) else { return false }
            guard case .settled = refinement.settling(value) else { return false }

            return true

        case .bool:
            return candidate == "true" || candidate == "false"

        // An unbounded type parameter is filled by the call, so nothing about
        // the candidates is knowable here. A bounded one takes only what some
        // member of its constraint could spell.
        case let .parameter(_, constraint):
            guard let constraint else { return true }

            return table.constraints[constraint].contains { member in member.spells(candidate, in: table) }

        case let .named(row):
            return table.shapes[row].spells(candidate, in: table)

        // A candidate spells a value, and null is not one a `oneOf` lists, so
        // a nullable slot's candidates are the declared half's.
        case let .nullable(inner), let .variable(inner), let .inout(inner):
            return inner.spells(candidate, in: table)

        case .null, .never, .bytes, .array, .dictionary, .record, .procedure:
            return false
        }
    }

    // Whether two shapes are one shape, names resolved. `any` is no wildcard
    // here and neither is a type parameter: standing for anything is what
    // `accepts` reads, and a body free to write anything into a variable the
    // caller declared is the disagreement this refuses.
    func same(_ other: Shape, in table: ShapeTable) -> Bool {
        same(other, in: table, assuming: [])
    }

    func same(_ other: Shape, in table: ShapeTable, assuming: [(Shape, Shape)]) -> Bool {
        if assuming.contains(where: { mine, theirs in mine == self && theirs == other }) { return true }

        let walked = assuming + [(self, other)]

        switch (self, other) {
        case (.undeclared, _), (_, .undeclared), (.parameter, _), (_, .parameter):
            return true

        // A record under a name is that name, so two names are two shapes
        // however alike. Every other name is what it names.
        case let (.named(mine), .named(theirs)):
            guard mine != theirs else { return true }

            return table.recordRows[mine] == nil
                && table.recordRows[theirs] == nil
                && table.shapes[mine].same(table.shapes[theirs], in: table, assuming: walked)

        case let (.named(mine), _):
            return table.recordRows[mine] == nil
                && table.shapes[mine].same(other, in: table, assuming: walked)

        case let (_, .named(theirs)):
            return table.recordRows[theirs] == nil
                && same(table.shapes[theirs], in: table, assuming: walked)

        case let (.nullable(mine), .nullable(theirs)),
            let (.array(mine), .array(theirs)),
            let (.dictionary(mine), .dictionary(theirs)),
            let (.variable(mine), .variable(theirs)),
            let (.inout(mine), .inout(theirs)):
            return mine.same(theirs, in: table, assuming: walked)

        case let (.record(mine), .record(theirs)):
            return mine.layout == theirs.layout
                && zip(mine.fields, theirs.fields).allSatisfy { one, other in
                    one.same(other, in: table, assuming: walked)
                }

        case let (.procedure(mine, myAnswer, myPurity, myIsolation),
                  .procedure(theirs, theirAnswer, theirPurity, theirIsolation)):
            guard myPurity == theirPurity, myIsolation == theirIsolation else { return false }

            switch (myAnswer, theirAnswer) {
            case (nil, nil):
                break

            case let (myAnswer?, theirAnswer?):
                guard myAnswer.same(theirAnswer, in: table, assuming: walked) else { return false }

            default:
                return false
            }

            switch (mine, theirs) {
            case (nil, nil):
                return true

            case let (mine?, theirs?):
                return mine.count == theirs.count
                    && zip(mine, theirs).allSatisfy { one, other in
                        one.name == other.name
                            && one.mustBeGiven == other.mustBeGiven
                            && one.shape.same(other.shape, in: table, assuming: walked)
                    }

            default:
                return false
            }

        // Every shape that holds another is answered above; what is left
        // holds nothing.
        default:
            return self == other
        }
    }


    // One value of every kind a decided shape can hold, for asking the judge
    // rather than restating it.
    private static let witnesses: [Value] = [
        .null, .bool(false), .int(0), .double(0), .string(""),
        .array([]), .dictionary([:]), .bytes([])
    ]

    private func settles(_ value: Value, in table: ShapeTable) -> Bool {
        (try? settling(value, at: "", in: table)) != nil
    }
}
