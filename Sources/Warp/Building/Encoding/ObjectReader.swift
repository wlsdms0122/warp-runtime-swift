//
//  ObjectReader.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// A value read back as the object it was written from.
//
// The layout is the language's, under *objects* in the specification: the
// parts stand under their keys, and inside a part the fields stand in the
// order the page lays them down. What tells a reading that a writing was laid
// out some other way is the format number, read before anything else.
struct ObjectReader {
    // MARK: - Property
    // Which document this is reading an object of. Every identity a reading
    // makes is made here, and an identity is worth having because it is
    // derived and never declared: an object writes one down, so the reading
    // holds it to the one the object was kept under.
    private let identity: Identity?

    // What the caller kept this object under. Carried in for the reason the
    // identity is: what an object is, is worked out from its bytes, and
    // reading bytes is another package's.
    private let fingerprint: Fingerprint?

    // MARK: - Initializer
    init(of identity: Identity?, fingerprint: Fingerprint?) {
        self.identity = identity
        self.fingerprint = fingerprint
    }

    // MARK: - Internal
    func compiled(from value: Value) throws -> Compiled {
        var fields = try Keyed(value, of: "object")

        // The layout first, and before anything laid out by it: what this
        // number says is whether the rest of the keys mean what this reading
        // takes them to mean.
        let format = try Fields.count(try fields.take(Compiled.formatKey), of: "object")

        guard format == Compiled.format else {
            throw ObjectRefused(
                "the object is laid out as format \(format), and this reads format \(Compiled.format)"
            )
        }

        let document = try document(fields.take("document"))
        let dependencies = try Fields.ordered(fields.take("dependencies"), of: "dependencies") { written in
            Fingerprint(try Fields.bytes(written, of: "dependencies"))
        }
        let types = try keyed(fields.take("types"), of: "types", expression)
        let constraints = try keyed(fields.take("constraints"), of: "constraints") { written in
            try Fields.list(written, of: "constraints", expression)
        }
        let contracts = try keyed(fields.take("contracts"), of: "contracts") { written in
            try keyed(written, of: "contract", signature)
        }
        let claims = try keyed(fields.take("claims"), of: "claims") { written in
            Set(try Fields.ordered(written, of: "claims", name))
        }
        let leaned = try leaned(fields.take("leaned"))

        // The rows the document declares stand under their spellings, and
        // those spellings are what the numbering counts from. The rows its
        // bodies lifted are spelled by the numbering, so they are read once
        // it is.
        let declaredRows = try Fields.list(fields.take("rows"), of: "rows") { written in try judged(written, spelled: nil) }
        let liftedRows = try Fields.list(fields.take("lifted"), of: "lifted") { written in written }
        let declared = declaredRows.map(\.label)

        // One row per spelling, in name order: what the numbering counts
        // from and what a link looks a spelling up in both stand on it.
        guard declared.ordered else {
            throw ObjectRefused("the declared rows stand out of name order, or one spelling stands twice")
        }
        let answers = try keyed(fields.take("answers"), of: "answers", lowered)

        // Four lists: what the document sends, how many closures each
        // declaration wrote, the types its bodies stand on, the memberships.
        var counted = try Fields(fields.take("numbering"), of: "numbering")
        let numbering = try Numbering(written: .array([try counted.next(), try counted.next()]), declaring: declared)
        let table = declaredRows + (try liftedRows.enumerated().map { index, written in
            guard let writer = numbering.writer(of: index) else {
                throw ObjectRefused("a lifted row stands where the numbering counts no closure")
            }

            return try judged(written, spelled: writer.by)
        })
        let typeNumbering = try typeNumbering(.array([try counted.next(), try counted.next()]))

        try counted.end()

        let variables = try Fields.list(fields.take("variables"), of: "variables", variable)
        let constants = try Fields.ordered(fields.take("constants"), of: "constants", name)
        let read = try Compiled(
            document: document,
            types: types,
            constraints: constraints,
            contracts: contracts,
            claims: claims,
            leaned: leaned,
            declared: declared,
            constants: constants,
            table: table,
            answers: answers,
            numbering: numbering,
            typeNumbering: typeNumbering,
            judging: variables,
            dependencies: dependencies,
            fingerprint: fingerprint
        )

        try fields.end()

        return read
    }

    // MARK: - Private
    private func keyed<T>(
        _ value: Value,
        of part: String,
        _ read: (Value) throws -> T
    ) throws -> [Name: T] {
        try Fields.gathered(try Fields.list(value, of: part) { entry in
            var fields = try Fields(entry, of: part)
            let held = (try fields.name(), try read(fields.next()))

            try fields.end()

            return held
        }, of: part)
    }

    // A reading that goes through a door the value layer judges. A type of
    // that layer knows nothing of objects, so what it refuses is said again
    // in the words this reading answers in. The build's own types say it
    // themselves and are called plainly.
    private func refusing<T>(_ read: () throws -> T) throws -> T {
        do {
            return try read()
        } catch let refused as ValueRefused {
            throw ObjectRefused(refused.message)
        }
    }

    private func name(_ value: Value) throws -> Name {
        try Fields.name(value, of: "a name")
    }

    private func document(_ value: Value) throws -> Place.Document {
        let read = try Fields.maybe(value, of: "document") { written in
            Identity(try Fields.bytes(written, of: "document"))
        }

        guard read == identity else {
            throw ObjectRefused(
                "this object stands against a document other than the one it was kept under"
            )
        }

        return Place.Document(identity: read)
    }

    // The document a closure's writer stands in, which may be another
    // document's: a closure a fold settled came out of whatever the fold ran.
    // The writing spells no document nobody wrote down, so a writer with
    // none is one the writing never laid down.
    private func writing(_ value: Value) throws -> Closure.Document {
        .written(Identity(try Fields.bytes(value, of: "writer")))
    }

    // The document a place inside this object is an address in.
    private func held(_ value: Value) throws -> Place.Document {
        Place.Document(
            identity: try Fields.maybe(value, of: "place document") { written in
                Identity(try Fields.bytes(written, of: "place document"))
            }
        )
    }

    private func leaned(_ value: Value) throws -> [Claim: Place] {
        try Fields.gathered(try Fields.list(value, of: "leaned") { entry in
            var fields = try Fields(entry, of: "leaned")
            let claim = Claim(type: try name(fields.next()), contract: try name(fields.next()))
            let where_ = try place(fields.next())

            try fields.end()

            return (claim, where_)
        }, of: "leaned")
    }

    private func variable(_ value: Value) throws -> (name: Name, value: Value) {
        var fields = try Fields(value, of: "variable")
        let read = (name: try name(fields.next()), value: try self.value(fields.next()))

        try fields.end()

        return read
    }
}

extension ObjectReader {
    // A value as the writing laid it down: data as it is, and a closure by
    // what it is spelled by, standing without a row until a link answers one.
    func value(_ value: Value) throws -> Value {
        var fields = try Fields(value, of: "value")
        let read: Value

        switch ValueTag(rawValue: try fields.tag()) {
        case .null: read = .null
        case .bool:
            guard case let .bool(held) = try fields.next() else {
                throw ObjectRefused("'value' writes something other than a bool where one stands")
            }

            read = .bool(held)

        case .int: read = .int(try fields.integer())
        case .double: read = .double(try fields.double())
        case .string: read = .string(try fields.text())
        case .bytes: read = .bytes(try Fields.bytes(fields.next(), of: "value"))
        case .array: read = .array(try fields.list(self.value))

        // A value the model refuses is one the writing could not have laid
        // down, and so one this reading refuses as an object.
        case .record:
            let named = try fields.maybe(name)
            let names = try fields.list(name)
            let values = try fields.list(self.value)

            read = try refusing {
                .record(try Record(layout: try Layout(name: named, judging: names), checking: values))
            }

        case .dictionary:
            let entries = try fields.list { entry -> (name: Name, value: Value) in
                var fields = try Fields(entry, of: "entry")
                let read = (name: try name(fields.next()), value: try self.value(fields.next()))

                try fields.end()

                return read
            }

            read = try refusing { .dictionary(try Value.Dictionary(entries)) }

        case .closure:
            let writer = Closure.Writer(document: try writing(fields.next()), name: try name(fields.next()))
            let nth = try fields.count()
            let captured = try fields.list { cell -> (slot: Int, cell: Cell) in
                var fields = try Fields(cell, of: "captured")
                let read = (slot: try fields.count(), cell: Cell.value(try self.value(fields.next())))

                try fields.end()

                return read
            }

            read = .procedure(Closure(writer: writer, nth: nth, linked: nil, captured: captured))

        case nil: throw ObjectRefused("'value' answers in a way this reads none of")
        }

        try fields.end()

        return read
    }
}

private extension ObjectReader {
    func expression(_ value: Value) throws -> TypeExpression {
        var fields = try Fields(value, of: "type")
        let read: TypeExpression

        switch try fields.tag() {
        case 0: read = .any
        case 1: read = .never
        case 2: read = .null
        case 3: read = .bool
        case 4: read = .int
        case 5: read = .double
        case 6: read = .string
        case 7: read = .ranged(try ranged(fields.next()))
        case 8: read = .array(try expression(fields.next()))
        case 9: read = .dictionary(try expression(fields.next()))
        case 10: read = .record(try keyed(fields.next(), of: "record", expression))
        case 11:
            read = .procedure(
                try fields.maybe(signature),
                try constness(fields.next()),
                try isolation(fields.next())
            )

        case 12: read = .variable(try expression(fields.next()))
        case 13: read = .inout(try expression(fields.next()))
        case 14: read = .linear(try expression(fields.next()))
        case 15: read = .consuming(try expression(fields.next()))
        case 16: read = .borrowing(try expression(fields.next()))
        case 17: read = .nullable(try expression(fields.next()))
        case 18: read = .named(try name(fields.next()))
        case 19:
            read = .parameter(
                name: try name(fields.next()),
                constraints: try Fields.ordered(fields.next(), of: "bounds", name)
            )

        case 20:
            read = .reading(
                of: try name(fields.next()),
                path: try Fields.list(fields.next(), of: "path", segment)
            )

        case 21:
            let names = try Fields.ordered(fields.next(), of: "composition", name)

            guard !names.isEmpty else {
                throw ObjectRefused("'composition' joins nothing")
            }

            read = .composition(names)

        default:
            throw ObjectRefused("'type' names a kind this reads none of")
        }

        try fields.end()

        return read
    }

    func ranged(_ value: Value) throws -> TypeExpression.Refinement {
        var fields = try Fields(value, of: "range")
        let read: TypeExpression.Refinement

        switch try fields.tag() {
        case 0:
            read = .whole(
                from: try fields.maybe(integer),
                to: try fields.maybe { written in try edge(written, integer) }
            )

        case 1:
            read = .fraction(
                from: try fields.maybe(fraction),
                to: try fields.maybe { written in try edge(written, fraction) }
            )

        default:
            throw ObjectRefused("'range' is over neither whole numbers nor fractions")
        }

        try fields.end()

        return read
    }

    func edge<Bound>(
        _ value: Value,
        _ read: (Value) throws -> Bound
    ) throws -> TypeExpression.Refinement.Edge<Bound> {
        var fields = try Fields(value, of: "edge")
        let held: TypeExpression.Refinement.Edge<Bound>

        switch try fields.tag() {
        case 0: held = .through(try read(fields.next()))
        case 1: held = .upTo(try read(fields.next()))
        default: throw ObjectRefused("'edge' says neither that its bound is inside nor that it is out")
        }

        try fields.end()

        return held
    }

    func counted(_ value: Value) throws -> Int {
        try Fields.count(value, of: "a count")
    }

    func integer(_ value: Value) throws -> Int {
        try Fields.integer(value, of: "a number")
    }

    func fraction(_ value: Value) throws -> Double {
        try Fields.double(value, of: "a fraction")
    }

    func text(_ value: Value) throws -> String {
        try Fields.text(value, of: "a text")
    }

    func segment(_ value: Value) throws -> PathSegment {
        var fields = try Fields(value, of: "path segment")
        let read: PathSegment

        switch try fields.tag() {
        case 0: read = .key(try name(fields.next()), optional: try fields.flag())
        case 1: read = .index(try fields.integer(), optional: try fields.flag())
        case 2:
            read = .indexRef(
                try Fields.list(fields.next(), of: "path", segment),
                optional: try fields.flag()
            )

        default:
            throw ObjectRefused("'path segment' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }

    func signature(_ value: Value) throws -> Signature {
        var fields = try Fields(value, of: "signature")
        let read = Signature(
            receiver: try fields.maybe(name),
            parameters: try keyed(fields.next(), of: "parameters", parameter),
            returns: try fields.maybe(expression)
        )

        try fields.end()

        return read
    }

    func parameter(_ value: Value) throws -> Parameter {
        var fields = try Fields(value, of: "parameter")
        let read = Parameter(
            type: try fields.maybe(expression),
            candidates: try fields.maybe { written in try Fields.list(written, of: "candidates", text) },
            default: try fields.maybe { written in try self.value(written) },
            description: try fields.maybe(text)
        )

        try fields.end()

        return read
    }

    func constness(_ value: Value) throws -> Constness {
        switch try integer(value) {
        case 0: return .unstated
        case 1: return .const
        default: throw ObjectRefused("'constness' says neither that it is stated nor that it is const")
        }
    }

    func isolation(_ value: Value) throws -> Isolation {
        switch try integer(value) {
        case 0: return .unstated
        case 1: return .isolated
        default: throw ObjectRefused("'isolation' says neither that it is stated nor that it is isolated")
        }
    }

    func failing(_ value: Value) throws -> Failing {
        var fields = try Fields(value, of: "failing")
        let read: Failing

        switch try fields.tag() {
        case 0: read = .unstated
        case 1:
            read = .these(Set(try Fields.ordered(fields.next(), of: "failing", text)))
        default: throw ObjectRefused("'failing' says neither nothing nor which failures")
        }

        try fields.end()

        return read
    }
}

private extension ObjectReader {
    func place(_ value: Value) throws -> Place {
        var fields = try Fields(value, of: "place")
        let stands = try held(fields.next())
        let read = Place(try Fields.list(fields.next(), of: "place", step), in: stands)

        try fields.end()

        return read
    }

    func step(_ value: Value) throws -> Place.Step {
        var fields = try Fields(value, of: "place step")
        let read: Place.Step

        switch try fields.tag() {
        case 0: read = .key(try fields.text())
        case 1: read = .part(try part(fields.next()))
        case 2: read = .construct(try construct(fields.next()))
        case 3: read = .index(try fields.integer())
        case 4: read = .statement(name: try fields.maybe(text), at: try fields.integer())
        case 5: read = .landmark(try fields.text())
        default: throw ObjectRefused("'place step' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }

    func part(_ value: Value) throws -> Place.Part {
        var fields = try Fields(value, of: "part")
        let read: Place.Part

        switch try fields.tag() {
        case 0: read = .procedures
        case 1: read = .constants
        case 2: read = .variables
        case 3: read = .types
        case 4: read = .constraints
        case 5: read = .contracts
        case 6: read = .satisfies
        case 7: read = .imports
        case 8: read = .parameters
        case 9: read = .returns
        case 10: read = .body
        case 11: read = .result
        case 12: read = .receiver
        case 13: read = .callee
        case 14: read = .arguments
        case 15: read = .closure
        case 16: read = .condition(of: try holder(fields.next()))
        case 17: read = .then
        case 18: read = .otherwise
        case 19: read = .rescue
        default: throw ObjectRefused("'part' names a part this reads none of")
        }

        try fields.end()

        return read
    }

    func holder(_ value: Value) throws -> Place.ConditionHolder {
        var fields = try Fields(value, of: "condition holder")
        let read: Place.ConditionHolder

        switch try fields.tag() {
        case 0: read = .conditional
        case 1: read = .loop
        default: throw ObjectRefused("'condition holder' holds a condition in no way this reads")
        }

        try fields.end()

        return read
    }

    func construct(_ value: Value) throws -> Construct {
        var fields = try Fields(value, of: "construct")
        let read: Construct

        switch try fields.tag() {
        case 0: read = .literal
        case 1: read = .reference
        case 2: read = .array
        case 3: read = .record
        case 4: read = .closure
        case 5: read = .cast
        case 6: read = .apply
        case 7: read = .block
        case 8: read = .conditional
        case 9: read = .loop
        case 10: read = .attempt
        case 11: read = .call
        case 12: read = .leave(try reach(fields.next()))
        default: throw ObjectRefused("'construct' names a construct this reads none of")
        }

        try fields.end()

        return read
    }

    func reach(_ value: Value) throws -> Leave.Reach {
        switch try integer(value) {
        case 0: return .procedure
        case 1: return .construct
        case 2: return .round
        default: throw ObjectRefused("'leave' reaches nothing this reads")
        }
    }

    func layout(_ value: Value) throws -> Layout {
        var fields = try Fields(value, of: "layout")
        let named = try fields.maybe(name)
        let written = try Fields.list(fields.next(), of: "layout", name)

        try fields.end()

        // Through the door that judges rather than the one that orders. What
        // stands beside a layout here is a list of values read on its own, and
        // a reading that put the names in order would pair them with values
        // that never moved.
        return try refusing { try Layout(name: named, judging: written) }
    }
}

private extension ObjectReader {
    func lowered(_ value: Value) throws -> LoweredType {
        var fields = try Fields(value, of: "lowered type")
        let read: LoweredType

        switch try fields.tag() {
        case 0: read = .any
        case 1: read = .never
        case 2: read = .null
        case 3: read = .bool
        case 4: read = .int
        case 5: read = .double
        case 6: read = .string
        case 7: read = .ranged(try ranged(fields.next()))
        case 8: read = .array(try lowered(fields.next()))
        case 9: read = .dictionary(try lowered(fields.next()))
        case 10: read = .record(try loweredRecord(fields.next()))
        case 11:
            read = .procedure(
                parameters: try fields.maybe { written in
                    try Fields.list(written, of: "parameters") { parameter in
                        var held = try Fields(parameter, of: "parameter")
                        let taken = LoweredParameter(
                            name: try name(held.next()),
                            type: try lowered(held.next()),
                            mustBeGiven: try held.flag()
                        )

                        try held.end()

                        return taken
                    }
                },
                returns: try fields.maybe(lowered),
                constness: try constness(fields.next()),
                isolation: try isolation(fields.next())
            )

        case 12: read = .variable(try lowered(fields.next()))
        case 13: read = .inout(try lowered(fields.next()))
        case 14: read = .nullable(try lowered(fields.next()))
        case 15: read = .named(try fields.count())
        case 16:
            read = .parameter(label: try name(fields.next()), bounds: try Fields.ordered(fields.next(), of: "bounds", bound))

        case 18:
            read = .reading(
                of: try name(fields.next()),
                path: try Fields.list(fields.next(), of: "path", segment)
            )

        case 19: read = .undeclared(label: try fields.text(), because: try undeclared(fields.next()))
        case 17:
            let bounds = try Fields.ordered(fields.next(), of: "composition", bound)

            guard !bounds.isEmpty else {
                throw ObjectRefused("'composition' holds a value to nothing")
            }

            read = .composition(bounds)

        default: throw ObjectRefused("'lowered type' names a kind this reads none of")
        }

        try fields.end()

        return read
    }

    func undeclared(_ value: Value) throws -> LoweredType.Undeclared {
        var fields = try Fields(value, of: "undeclared")
        let read: LoweredType.Undeclared

        switch try fields.tag() {
        case 0: read = .type(try name(fields.next()))
        case 1: read = .bound(try name(fields.next()))
        case 2: read = .cycle
        default: throw ObjectRefused("'undeclared' is undeclared for a reason this reads none of")
        }

        try fields.end()

        return read
    }

    func bound(_ value: Value) throws -> LoweredType.Bound {
        var fields = try Fields(value, of: "bound")
        let read: LoweredType.Bound

        switch try fields.tag() {
        case 0: read = .membership(try fields.count())
        case 1: read = .contract(try name(fields.next()))
        default: throw ObjectRefused("'bound' holds a parameter to nothing this reads")
        }

        try fields.end()

        return read
    }

    func loweredRecord(_ value: Value) throws -> LoweredRecord {
        var fields = try Fields(value, of: "record")
        let held = try layout(fields.next())
        let read = try LoweredRecord(
            layout: held,
            judging: try Fields.list(fields.next(), of: "record", lowered)
        )

        try fields.end()

        return read
    }

    func typeNumbering(_ value: Value) throws -> LoweredTypeNumbering {
        var fields = try Fields(value, of: "type numbering")
        let types = try Fields.list(fields.next(), of: "type numbering", name)
        let memberships = try Fields.list(fields.next(), of: "type numbering", name)
        let read = try LoweredTypeNumbering(ordered: types, memberships: memberships)

        try fields.end()

        return read
    }
}

private extension ObjectReader {
    // A declared row carries its spelling; a lifted row is handed the one
    // its numbering answers.
    func judged(_ value: Value, spelled: Name?) throws -> Judged {
        var fields = try Fields(value, of: "row")
        let label = try spelled ?? name(fields.next())
        let signature = try signature(fields.next())
        let read = try Judged(
            label: label,
            signature: signature,
            constness: try constness(fields.next()),
            isolation: try isolation(fields.next()),
            failing: try failing(fields.next()),
            sends: try Fields.list(fields.next(), of: "row", sent),
            judging: try implementation(fields.next())
        )

        try fields.end()

        return read
    }

    func implementation(_ value: Value) throws -> Judged.Implementation {
        var fields = try Fields(value, of: "implementation")
        let read: Judged.Implementation

        switch try fields.tag() {
        case 0: read = .body(try body(fields.next()), try frame(fields.next()))

        case 1: read = .native(sending: try Fields.list(fields.next(), of: "sending", send))
        default: throw ObjectRefused("'implementation' answers in a way this reads none of")
        }

        try fields.end()

        return read
    }

    func sent(_ value: Value) throws -> Sent {
        var fields = try Fields(value, of: "send")
        let read = Sent(
            row: try fields.count(),
            handing: try Fields.list(fields.next(), of: "send", counted)
        )

        try fields.end()

        return read
    }

    func send(_ value: Value) throws -> Native.Send {
        var fields = try Fields(value, of: "native send")
        let read = Native.Send(
            position: try fields.count(),
            selector: try name(fields.next()),
            handing: try Fields.list(fields.next(), of: "native send", name)
        )

        try fields.end()

        return read
    }

    func frame(_ value: Value) throws -> Frame {
        var fields = try Fields(value, of: "frame")
        let size = try fields.count()
        let read = Frame(
            size: size,
            parameters: try Fields.list(fields.next(), of: "frame", counted),
            variables: try Fields.list(fields.next(), of: "frame") { written in
                var held = try Fields(written, of: "frame variable")
                let taken = (variable: try held.count(), slot: try held.count())

                try held.end()

                return taken
            },
            captures: try Fields.list(fields.next(), of: "frame", counted),
            names: try Fields.list(fields.next(), of: "frame", name)
        )

        try fields.end()

        return read
    }

    func body(_ value: Value) throws -> Body {
        var fields = try Fields(value, of: "body")
        let read = Body(
            instructions: try Fields.list(fields.next(), of: "body", instruction),
            result: try fields.maybe(operation)
        )

        try fields.end()

        return read
    }

    func instruction(_ value: Value) throws -> Instruction {
        var fields = try Fields(value, of: "instruction")
        let read = Instruction(
            binding: try fields.maybe(binding),
            code: try operation(fields.next()),
            label: try fields.text()
        )

        try fields.end()

        return read
    }

    func binding(_ value: Value) throws -> Instruction.Binding {
        var fields = try Fields(value, of: "binding")
        let read: Instruction.Binding

        switch try fields.tag() {
        case 0: read = .bind(try fields.count(), settling: try fields.maybe(lowered))
        case 1: read = .declare(try fields.count(), settling: try fields.maybe(lowered))
        case 2: read = .assign(try address(fields.next()), settling: try fields.maybe(lowered))
        default: throw ObjectRefused("'binding' binds in a way this reads none of")
        }

        try fields.end()

        return read
    }

    func address(_ value: Value) throws -> Address {
        var fields = try Fields(value, of: "address")
        let read = Address(
            slot: try fields.count(),
            steps: try Fields.list(fields.next(), of: "address", walk)
        )

        try fields.end()

        return read
    }

    func walk(_ value: Value) throws -> Step {
        var fields = try Fields(value, of: "walk")
        let read: Step

        switch try fields.tag() {
        case 0:
            read = .field(try fields.count(), try name(fields.next()), optional: try fields.flag())

        case 1: read = .key(try name(fields.next()), optional: try fields.flag())
        case 2: read = .index(try fields.integer(), optional: try fields.flag())
        case 3: read = .at(try address(fields.next()), optional: try fields.flag())
        default: throw ObjectRefused("'walk' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }
}

private extension ObjectReader {
    func operation(_ value: Value) throws -> Operation {
        var fields = try Fields(value, of: "operation")
        let read: Operation

        switch try fields.tag() {
        case 0: read = .literal(try self.value(fields.next()))
        case 1: read = .local(try address(fields.next()))
        case 2: read = .array(try Fields.list(fields.next(), of: "array", operation))
        case 3: read = .record(try recordOperation(fields.next()))
        case 4:
            read = .closure(
                try fields.count(),
                captures: try Fields.list(fields.next(), of: "captures") { written in
                    var held = try Fields(written, of: "capture")
                    let taken = (try held.count(), try held.count())

                    try held.end()

                    return taken
                }
            )

        case 5:
            read = .apply(
                try operation(fields.next()),
                arguments: try Fields.list(fields.next(), of: "arguments") { written in
                    var held = try Fields(written, of: "argument")
                    let taken = (try name(held.next()), try operation(held.next()))

                    try held.end()

                    return taken
                }
            )

        case 6:
            read = .cast(
                try operation(fields.next()),
                as: try lowered(fields.next()),
                optional: try fields.flag()
            )

        case 7: read = .block(try body(fields.next()))
        case 8:
            read = .conditional(
                try operation(fields.next()),
                then: try Fields.list(fields.next(), of: "then", instruction),
                else: try fields.maybe { written in
                    try Fields.list(written, of: "otherwise", instruction)
                }
            )

        case 9:
            read = .loop(
                while: try operation(fields.next()),
                body: try body(fields.next()),
                round: try fields.count(),
                keeps: try fields.maybe { written in
                    var held = try Fields(written, of: "keeps")
                    let low = try held.count()
                    let high = try held.count()

                    try held.end()

                    guard low <= high else {
                        throw ObjectRefused("'keeps' ends before it begins")
                    }

                    return low ..< high
                }
            )

        case 10:
            read = .attempt(
                try body(fields.next()),
                rescue: try body(fields.next()),
                failure: try fields.count()
            )

        case 11: read = .call(try callOperation(fields.next()))
        case 12: read = .dispatch(try dispatchOperation(fields.next()))
        case 13:
            read = .leave(
                try reach(fields.next()),
                target: try fields.maybe(name),
                try fields.maybe(operation)
            )

        default:
            throw ObjectRefused("'operation' does something this reads none of")
        }

        try fields.end()

        return read
    }

    func recordOperation(_ value: Value) throws -> RecordOperation {
        var fields = try Fields(value, of: "record")
        let held = try layout(fields.next())
        let read = try RecordOperation(
            layout: held,
            judging: try Fields.list(fields.next(), of: "record", operation)
        )

        try fields.end()

        return read
    }

    func callOperation(_ value: Value) throws -> CallOperation {
        var fields = try Fields(value, of: "call")
        let read = try CallOperation(
            procedure: try fields.count(),
            receiver: try fields.maybe(operation),
            arguments: try Fields.list(fields.next(), of: "arguments") { written in
                try Fields.maybe(written, of: "argument", operation)
            },
            judging: try Fields.list(fields.next(), of: "handed") { written in
                var held = try Fields(written, of: "handed")
                let taken = CallOperation.Handed(
                    position: try held.count(),
                    address: try address(held.next())
                )

                try held.end()

                return taken
            }
        )

        try fields.end()

        return read
    }

    func dispatchOperation(_ value: Value) throws -> DispatchOperation {
        var fields = try Fields(value, of: "dispatch")
        let read = DispatchOperation(
            contract: try name(fields.next()),
            procedure: try name(fields.next()),
            receiver: try operation(fields.next()),
            arguments: try keyed(fields.next(), of: "arguments", argument)
        )

        try fields.end()

        return read
    }

    func argument(_ value: Value) throws -> Argument {
        var fields = try Fields(value, of: "argument")
        let read: Argument

        switch try fields.tag() {
        case 0: read = .value(try operation(fields.next()))
        case 1: read = .reference(try address(fields.next()))
        default: throw ObjectRefused("'argument' is handed in a way this reads none of")
        }

        try fields.end()

        return read
    }
}
