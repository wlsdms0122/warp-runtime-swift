//
//  LoweredType+Settling.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The value judge: what a shape accepts, settled to the declared
// representation, or a refusal saying which part disagreed. The one judge
// for a value crossing a declaration, at the link and at the run alike.
extension LoweredType {
    // `at` is the path into the value so the message names the field rather
    // than the whole argument. `assuming` is which constraints are already
    // being asked of this value: a bounded parameter's membership test
    // settles the value against each member, and a member reaching a
    // bounded parameter again walks back into the same question, so met
    // again it is assumed rather than asked.
    func settling(
        _ value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int] = []
    ) throws -> Value {
        switch self {
        case .any, .reading:
            return value

        // Both ask the membership and neither settles: a value stands as what
        // it arrived as, and which member it matched is a question a cast asks.
        case let .parameter(_, bound):
            return try standing(value, boundBy: bound, at: path(), in: table, assuming: assuming)

        case let .member(constraint):
            return try standing(value, boundBy: .membership(constraint), at: path(), in: table, assuming: assuming)

        default:
            return try judging(value, at: path(), in: table, assuming: assuming)
        }
    }

    // What a cast does, said once. The judgment is `settling`'s; what this
    // adds is the one thing the cast spelling decides: what a mismatch means.
    func reading(_ value: Value, optional: Bool, in table: LoweredTypeTable) throws -> Value {
        do {
            return try settling(value, at: "as \(rendered(in: table))", in: table)
        } catch let mismatch as ArgumentError {
            // Only a mismatch is read as the author's expectation. Naming what
            // is absorbed rather than what is not keeps the default closed:
            // an error kind added later surfaces instead of quietly becoming
            // null.
            guard optional else {
                // Recoverable, unlike the same refusal at a parameter's
                // boundary: a cast is the author expecting a shape of data
                // that came from outside, and being wrong about that is what
                // the world does. An `attempt` catches it.
                throw CastRefused(
                    mismatch.message,
                    expected: rendered(in: table),
                    actual: "\(value.type)"
                )
            }

            return .null
        }
    }

    // Whether a scalar member admits a value: by kind, with the one widening,
    // and without settling. Nil for a member that is not a scalar, which is
    // judged by settling the value against it.
    func admitsAsScalar(_ value: Value) -> Bool? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double), (.double, .int),
            (.string, .string):
            return true

        case (.null, _), (.bool, _), (.int, _), (.double, _), (.string, _):
            return false

        default:
            return nil
        }
    }

    // Whether null is one of this type's values rather than an absence: the
    // fact `T?` exists to declare, and the boundary reads it. `any` is not
    // this: an undeclared shape accepts a null that arrives, but it does not
    // spell null as a value.
    func declaresNull(in table: LoweredTypeTable) -> Bool {
        switch self {
        case .null, .nullable:
            return true

        case let .named(row):
            return table.loweredTypes[row].declaresNull(in: table)

        // A value of a membership is one of its members, so null is spelled
        // here wherever a member spells it.
        case let .member(constraint):
            return table.constraints[constraint].contains { member in member.declaresNull(in: table) }

        default:
            return false
        }
    }

    // Whether a call must write a slot of this shape. A default answers
    // omission with a value; a shape that declares null answers it with the
    // null it holds. Without either, omission is a missing argument.
    func mustBeGiven(default fallback: Value?, in table: LoweredTypeTable) -> Bool {
        fallback == nil && !declaresNull(in: table)
    }

    // Whether every byte settles into this element declaration as itself,
    // unchanged and with nothing asked of any one of them. This is what lets
    // a compact spelling cross a boundary whole. It says the same thing
    // `settling` says one byte at a time, and a test holds the two together.
    //
    // The two sets are two namespaces: a table may bind one spelling as a
    // type and as a constraint, and folding the guards into one would let a
    // type's row end a constraint's question by assuming it.
    func holdsEveryByte(
        in table: LoweredTypeTable,
        namedAssuming: [Int] = [],
        boundAssuming: [Int] = []
    ) -> Bool {
        switch self {
        case .any, .reading, .int, .number:
            return true

        case let .variable(inner), let .inout(inner), let .nullable(inner):
            return inner.holdsEveryByte(in: table, namedAssuming: namedAssuming, boundAssuming: boundAssuming)

        // A parameter stands for what arrived and does not settle it. A
        // bounded one still asks each value for its membership, and a member
        // that takes every byte answers that question for all of them at
        // once.
        case let .parameter(_, bound):
            guard case let .membership(constraint)? = bound else { return true }

            return holdsEveryByte(
                of: constraint,
                in: table,
                namedAssuming: namedAssuming,
                boundAssuming: boundAssuming
            )

        // A value here is one of the members, so the membership answers this
        // the way it answers for a parameter it bounds.
        case let .member(constraint):
            return holdsEveryByte(
                of: constraint,
                in: table,
                namedAssuming: namedAssuming,
                boundAssuming: boundAssuming
            )

        case let .ranged(refinement):
            return refinement.holdsEveryByte

        case let .named(row):
            guard !namedAssuming.contains(row) else { return false }

            return table.loweredTypes[row].holdsEveryByte(
                in: table,
                namedAssuming: namedAssuming + [row],
                boundAssuming: boundAssuming
            )

        // `double` is the one widening the language has, so it changes every
        // byte it takes; the rest take no byte at all. Named rather than left
        // to a default, so that a kind added to the type language has to be
        // answered for here too.
        case .never, .null, .bool, .double, .string, .bytes,
             .array, .dictionary, .record, .procedure, .undeclared:
            return false
        }
    }

    // A candidate of `enum` read as the number its canonical spelling names
    // for this slot: a fraction slot reads only fraction spellings, so the
    // boundary and the link agree on which members exist. Nil where the
    // spelling names no number the slot takes.
    func numeral(_ candidate: String, in table: LoweredTypeTable) -> Value? {
        switch self {
        case .int:
            return Int(spelling: candidate).map(Value.int)

        // A range is a condition on a number, so the spelling it reads is the
        // spelling of the kind under it.
        case let .ranged(refinement):
            return refinement.lowered.numeral(candidate, in: table)

        case .double:
            return Double(spelling: candidate).map(Value.double)

        case let .named(row):
            return table.loweredTypes[row].numeral(candidate, in: table)

        case let .nullable(inner):
            return inner.numeral(candidate, in: table)

        // `number`, a parameter a constraint bounds, and the slots that
        // declare no numeric shape at all: the slot does not name one kind,
        // so a numeral is whichever kind's one spelling the text is.
        default:
            if let word = Int(spelling: candidate) { return .int(word) }

            return Double(spelling: candidate).map(Value.double)
        }
    }

    // Whether the types a membership admits take every byte between them.
    private func holdsEveryByte(
        of constraint: Int,
        in table: LoweredTypeTable,
        namedAssuming: [Int],
        boundAssuming: [Int]
    ) -> Bool {
        guard !boundAssuming.contains(constraint) else { return true }

        let deeper = boundAssuming + [constraint]

        if table.constraints[constraint].contains(where: { member in
            member.holdsEveryByte(in: table, namedAssuming: namedAssuming, boundAssuming: deeper)
        }) {
            return true
        }

        // No one member covers it, so the complete question is asked with the
        // boundary's own primitive: members that divide the range between them
        // still take every byte.
        return (0 ... 255).allSatisfy { byte in
            table.admits(constraint: constraint, value: .int(byte), assuming: deeper)
        }
    }

    // How the shape reads in a message: the spelling the author wrote, with
    // a row's label standing where the author wrote the name.
    func rendered(in table: LoweredTypeTable) -> String {
        switch self {
        case .any:
            return "any"

        // Spelled as what it is: the shape reached by that path. No document
        // writes this, so the spelling answers to the message alone, and an
        // author reading a refusal about `item.a` sees where it came from.
        case let .reading(of, path):
            return "some \(([PathSegment.key(of)] + path).rendered)"

        case .never:
            return "never"

        case .number:
            return "number"

        case .null:
            return "null"

        case .bool:
            return "bool"

        case .int:
            return "int"

        case .double:
            return "double"

        case .string:
            return "string"

        case .bytes:
            return "bytes"

        case let .ranged(refinement):
            return refinement.rendered

        case let .parameter(label, bound):
            switch bound {
            case let .membership(row):
                return "some \(label): \(table.constraintLabels[row])"

            case let .contract(name):
                return "some \(label): \(name)"

            case nil:
                return "some \(label)"
            }

        case let .member(constraint):
            return table.constraintLabels[constraint].spelling

        case let .variable(inner):
            return "var \(inner.rendered(in: table))"

        case let .inout(inner):
            return "inout \(inner.rendered(in: table))"

        case let .procedure(parameters, returns, purity, isolation):
            let word = [
                purity == .pure ? "pure" : nil,
                isolation == .isolated ? "isolated" : nil,
                "procedure"
            ]
            .compactMap { part in part }
            .joined(separator: " ")

            guard let parameters else { return word }

            let written = parameters.map { name, shape, _ in "\(name): \(shape.rendered(in: table))" }

            return "\(word)<(\(written.joined(separator: ", "))) -> \((returns ?? .any).rendered(in: table))>"

        case let .array(element):
            return "array<\(element.rendered(in: table))>"

        case let .dictionary(entry):
            return "dictionary<\(entry.rendered(in: table))>"

        case let .record(held):
            let written = held.named.map { name, field in
                "\(name): \(field.rendered(in: table))"
            }

            return "{ \(written.joined(separator: ", ")) }"

        case let .named(row):
            return table.labels[row].spelling

        case let .undeclared(label, _):
            return label

        case let .nullable(inner):
            return "\(inner.rendered(in: table))?"
        }
    }

    // MARK: - Private
    // Every shape that reads the value it is given. The two that do not are
    // answered by `settling` and never arrive here; reaching this by another
    // door sends them back to it.
    private func judging(
        _ value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        switch self {
        case .any, .reading, .parameter, .member:
            return try settling(value, at: path(), in: table, assuming: assuming)

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal: there is no shape to compare it against.
        case .never:
            throw ArgumentError("\(path()): declares never, and nothing is ever that")

        case let .undeclared(_, refusal):
            throw UndeclaredTypeError("\(path()): declares \(refusal)")

        // Either shape arrives as itself. Settling to one of them would be the
        // declaration picking, and it declined to.
        case .number:
            switch value {
            case .int, .double:
                return value

            default:
                throw mismatch(value, at: path(), in: table)
            }

        // A declared record is nominal. A record arriving without a name
        // settles to the declared shape and takes the name; one arriving
        // under this name is settled again and keeps it; one arriving under
        // another name is refused, whatever its shape. A declared name that is
        // not a record shape settles as the shape it stands for.
        case let .named(row):
            return try settlingNamed(value, row: row, at: path(), in: table, assuming: assuming)

        // Null arrives as itself; anything else is held to the declared half.
        case let .nullable(inner):
            guard value != .null else { return value }

            return try inner.settling(value, at: path(), in: table, assuming: assuming)

        case let .array(element):
            // Bytes are an array of bytes in a compact spelling, so they arrive
            // here as the array they are. Where the declaration leaves every
            // byte as it is, the compact spelling crosses whole: the slot
            // asked for an array and one is what it has, and unpacking it would
            // spend an element per byte to answer nothing.
            if case .bytes = value, element.holdsEveryByte(in: table, boundAssuming: assuming) {
                return value
            }

            // An element nothing was declared for passes as it is, so the
            // array does too: settling each element to itself would copy the
            // array to say nothing.
            if element == .any, case .array = value { return value }

            // Otherwise the slot's spelling wins the way `double` settles a
            // whole number, and both spellings are read through the one
            // projection that owns the equation.
            guard let items = value.elements else { throw mismatch(value, at: path(), in: table) }

            return .array(
                try items.enumerated().map { index, item in
                    try element.settling(item, at: "\(path())[\(index)]", in: table, assuming: assuming)
                }
            )

        // A dictionary slot holds the names as data, so a record settling
        // here becomes one, its layout's names written beside their values.
        case let .dictionary(entry):
            guard let held = value.asDictionary else { throw mismatch(value, at: path(), in: table) }

            if entry == .any { return .dictionary(held) }

            return .dictionary(
                try held.mapValues { _, item in
                    try entry.settling(item, at: path(), in: table, assuming: assuming)
                }
            )

        // An inline record is structural: a value holding at least these
        // fields fits it, whatever else it holds and whatever it is named.
        // Settling builds the slot's layout, so what settles here holds these
        // fields and no others.
        case let .record(held):
            return try settlingFields(value, of: held, at: path(), in: table, assuming: assuming)

        // A slot writes `var` or `inout` about itself; what stands in it is a
        // value of the inner type.
        case let .variable(inner), let .inout(inner):
            return try inner.settling(value, at: path(), in: table, assuming: assuming)

        // A closure carries what the link derived about its text, its purity
        // and its isolation, and a slot that asks for either reads the
        // carried fact. A closure that reached here through `any` or through
        // an undeclared field is judged here for the first time.
        case let .procedure(required, returns, purity, isolation):
            return try settlingProcedure(
                value,
                parameters: required,
                returns: returns,
                purity: purity,
                isolation: isolation,
                at: path(),
                in: table
            )

        // The bounds speak where the value does: a number inside them settles
        // as the kind's own value, and one outside is refused by the range
        // the declaration wrote.
        case let .ranged(refinement):
            switch refinement.settling(value) {
            case let .settled(settled):
                return settled

            case .otherKind:
                throw mismatch(value, at: path(), in: table)

            case let .outside(number):
                throw ArgumentError("\(path()): \(number) is outside \(rendered(in: table))")
            }

        // Bytes take their own spelling as themselves, and an array whose
        // every element is a byte's worth, settled to the compact spelling
        // the slot declared. The element judge is `byte`'s own, so what is
        // outside says which element and by how much.
        case .bytes:
            return try settlingBytes(value, at: path(), in: table, assuming: assuming)

        // The scalars, plus the one widening the language has, one way only:
        // an int where a double is declared. Nothing narrows; an int slot
        // refuses every fraction, `2.0` included.
        case .null, .bool, .int, .double, .string:
            guard let settled = scalar(value) else { throw mismatch(value, at: path(), in: table) }

            return settled
        }
    }

    // A type parameter the call site filled, and the link is where it was
    // filled. Unbounded, there is nothing left to compare against. A bounded
    // one still holds its constraint here: what arrived through `any` was
    // never read at the link, so membership is judged against the types the
    // constraint admits, and the value passes untouched. A parameter stands
    // for what arrived; it does not settle it.
    private func standing(
        _ value: Value,
        boundBy bound: LoweredType.Bound?,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        // A contract is answered by the value's own name: what the link found
        // to satisfy it is what a value may arrive as.
        //
        // A table that cannot say which types answer writes the pair down and
        // lets the value pass, so the list that holds every claim answers for
        // it. Where there is nowhere to write, there is nothing to wait for
        // and the value is held to what this table knows.
        if case let .contract(name)? = bound {
            switch table.settles(contract: name, arrived: value.nominal) {
            case true?:
                return value

            case nil:
                guard let type = value.nominal, let unsettled = table.unsettled else {
                    throw ArgumentError(
                        "\(path()): expected \(rendered(in: table)), and"
                            + " \(value.nominal.map { held in "'\(held)'" } ?? "\(value.type)")"
                            + " does not answer every word '\(name)' asks"
                    )
                }

                unsettled.require(folded: Claim(type: type, contract: name))

                return value

            case false?:
                let arrived = value.nominal.map { held in "'\(held)'" } ?? "\(value.type)"

                throw ArgumentError(
                    "\(path()): expected \(rendered(in: table)), and \(arrived)"
                        + " does not answer every word '\(name)' asks"
                )
            }
        }

        guard case let .membership(constraint)? = bound, !assuming.contains(constraint) else { return value }

        guard table.admits(constraint: constraint, value: value, assuming: assuming) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), and nothing"
                    + " '\(table.constraintLabels[constraint])' admits takes \(value.type)."
                    + " \(refused(value, by: constraint, at: path(), in: table, assuming: assuming))"
            )
        }

        return value
    }

    // Why each member of a membership said no, in one line. A membership
    // holding one shape of collection refuses a bad element, and the element
    // is what the author has to go and fix.
    private func refused(
        _ value: Value,
        by constraint: Int,
        at path: String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) -> String {
        let deeper = assuming + [constraint]

        return table.constraints[constraint]
            .map { member in
                // A scalar member says only that the kind is wrong, and the
                // kind is already in front of the reader.
                if member.admitsAsScalar(value) != nil {
                    return "as \(member.rendered(in: table)), got \(value.type)"
                }

                do {
                    _ = try member.settling(value, at: path, in: table, assuming: deeper)

                    return "as \(member.rendered(in: table)), got \(value.type)"
                } catch {
                    return "as \(member.rendered(in: table)), \(error)"
                }
            }
            .joined(separator: ". ")
    }

    private func settlingNamed(
        _ value: Value,
        row: Int,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        let declared = table.loweredTypes[row]

        guard value.holdsFields, let nominal = table.record(of: self) else {
            return try declared.settling(value, at: path(), in: table, assuming: assuming)
        }

        let label = table.labels[nominal]

        // A tag already canonical is the same spelling. One that is not
        // is an alias or another record, told apart by the table once.
        if case let .record(record) = value, let tag = record.name, tag != label {
            guard let spelled = table.row(named: tag), table.recordRows[spelled] == nominal else {
                throw ArgumentError("\(path()): is a \(tag), and the slot declares \(label)")
            }
        }

        guard case let .record(settled) = try declared.settling(value, at: path(), in: table, assuming: assuming) else {
            throw mismatch(value, at: path(), in: table)
        }

        return .record(settled.named(label))
    }

    private func settlingFields(
        _ value: Value,
        of held: LoweredRecord,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        guard value.holdsFields else { throw mismatch(value, at: path(), in: table) }

        return .record(
            Record(
                layout: held.layout,
                values: try held.named.map { name, field in
                    guard let given = value[name] else {
                        throw ArgumentError(
                            "\(path()).\(name): required by \(rendered(in: table)), and nothing was given"
                        )
                    }

                    return try field.settling(given, at: "\(path()).\(name)", in: table, assuming: assuming)
                }
            )
        )
    }

    private func settlingBytes(
        _ value: Value,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable,
        assuming: [Int]
    ) throws -> Value {
        switch value {
        case .bytes:
            return value

        case let .array(elements):
            let bytes = try elements.enumerated().map { index, item in
                let settled = try LoweredType.byteElement.settling(
                    item,
                    at: "\(path())[\(index)]",
                    in: table,
                    assuming: assuming
                )

                // `byte`'s own judge already spoke: what settled is an int
                // inside 0...255, which the canonical small form holds. A
                // miss here is this file's own defect.
                guard
                    case let .int(number) = settled,
                    let byte = UInt8(exactly: number)
                else {
                    preconditionFailure("a settled byte was not one")
                }

                return byte
            }

            return .bytes(bytes)

        default:
            throw mismatch(value, at: path(), in: table)
        }
    }

    private func settlingProcedure(
        _ value: Value,
        parameters required: [(name: Name, type: LoweredType, mustBeGiven: Bool)]?,
        returns: LoweredType?,
        purity: Purity,
        isolation: Isolation,
        at path: @autoclosure () -> String,
        in table: LoweredTypeTable
    ) throws -> Value {
        guard case let .procedure(closure) = value else { throw mismatch(value, at: path(), in: table) }

        // Its rows are numbered by the table of the link that made it.
        guard closure.linked.readable(in: table) else {
            throw ArgumentError("\(path()): \(Linked.unreadable)")
        }

        if purity == .pure, closure.purity != .pure {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got a procedure that runs"
            )
        }

        if isolation == .isolated, !closure.runsBeside {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got a procedure that writes"
                    + " what another body could touch"
            )
        }

        let given = LoweredType.procedure(
            parameters: closure.linked.slots.map { slot in
                (name: slot.name, type: slot.type, mustBeGiven: slot.mustBeGiven(in: table))
            },
            returns: closure.linked.returns,
            purity: closure.purity,
            isolation: closure.isolation
        )

        guard LoweredType.procedure(parameters: required, returns: returns, purity: .unstated, isolation: .unstated).accepts(given, in: table) else {
            throw ArgumentError(
                "\(path()): expected \(rendered(in: table)), got \(given.rendered(in: table))"
            )
        }

        return value
    }

    // The one conversion the language performs, and it goes one way: every
    // whole number is a fraction, so a slot asking for a fraction can take a
    // whole one and lose nothing.
    private func scalar(_ value: Value) -> Value? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double),
            (.string, .string):
            return value

        // The widening is binary64's own rounding, and every machine word has
        // a fraction near it: the conversion cannot fail, only round.
        case (.double, .int(let integer)):
            return .double(Double(integer))

        default:
            return nil
        }
    }

    private func mismatch(_ value: Value, at path: String, in table: LoweredTypeTable) -> ArgumentError {
        ArgumentError("\(path): expected \(rendered(in: table)), got \(value.type)")
    }
}
