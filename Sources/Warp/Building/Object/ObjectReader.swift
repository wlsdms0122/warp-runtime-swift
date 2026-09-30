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

    // MARK: - Public
    func compiled(from value: Value) throws -> Compiled {
        guard case .dictionary = value else {
            throw ObjectRefused("'object' is not written as a record")
        }

        // A document says `warp` where an object says `object`, and one handed
        // here is refused for what it is.
        if Keyed.peek(value, Module.versionKey) != nil {
            throw ObjectRefused("this is a document, and not an object")
        }

        // The layout first, and before anything laid out by it, the keys
        // included: what this number says is whether the rest of the record
        // means what this reading takes it to mean.
        guard let stamped = Keyed.peek(value, ObjectLayout.Key.object.name) else {
            throw ObjectRefused("'object' writes no '\(ObjectLayout.Key.object.name)'")
        }

        let format = try Fields.count(stamped, of: "object")

        guard format == ObjectLayout.format else {
            throw ObjectRefused(
                "the object is laid out as format \(format), and this reads format \(ObjectLayout.format)"
            )
        }

        let fields = try Keyed(value)

        let document = try document(fields.take(.document))
        let dependencies = try Fields.ordered(fields.take(.dependencies), of: "dependencies") { written in
            Fingerprint(try Fields.bytes(written, of: "dependencies"))
        }
        let types = try keyed(fields.take(.types), of: "types", expression)
        let constraints = try keyed(fields.take(.constraints), of: "constraints") { written in
            try Fields.list(written, of: "constraints", expression)
        }
        let contracts = try keyed(fields.take(.contracts), of: "contracts") { written in
            try keyed(written, of: "contract", contractProcedure)
        }
        let claims = try keyed(fields.take(.claims), of: "claims") { written in
            Set(try Fields.ordered(written, of: "claims", name))
        }
        let leaned = try leaned(fields.take(.leaned))

        // The rows the document declares stand under their spellings, and
        // those spellings are what the numbering counts from. The rows its
        // bodies lifted are spelled by the numbering, so they are read once
        // it is.
        let declaredRows = try Fields.list(fields.take(.rows), of: "rows") { written in try judged(written, spelled: nil) }
        let liftedRows = try Fields.list(fields.take(.lifted), of: "lifted") { written in written }
        let declared = declaredRows.map(\.label)

        // One row per spelling, in name order: what the numbering counts
        // from and what a link looks a spelling up in both stand on it.
        guard declared.ordered else {
            throw ObjectRefused("the declared rows stand out of name order, or one spelling stands twice")
        }
        let answers = try keyed(fields.take(.answers), of: "answers", lowered)

        // What the document sends and how many closures each declaration
        // wrote, which is what its bodies number their calls from.
        let numbering = try Numbering(written: fields.take(.numbering), declaring: declared)
        let table = declaredRows + (try liftedRows.enumerated().map { index, written in
            guard let writer = numbering.writer(of: index) else {
                throw ObjectRefused("a lifted row stands where the numbering counts no closure")
            }

            return try judged(written, spelled: writer.by.name)
        })
        // The types its bodies stand on and the memberships, which is what
        // they number their types from.
        let typeNumbering = try LoweredTypeNumbering(written: fields.take(.typeNumbering))

        let variables = try Fields.led(fields.take(.variables), of: "variables", variable)
        let constants = try Fields.ordered(fields.take(.constants), of: "constants", name)

        return try Compiled(
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
    }

    // A value as the writing laid it down: data as it is, and a closure by
    // what it is spelled by, standing without a row until a link answers one.
    func value(_ value: Value) throws -> Value {
        var fields = try Fields(value, of: "value")
        let read: Value

        switch ObjectLayout.ValueTag(rawValue: try fields.tag()) {
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
            let writer = Closure.Writer(
                document: try writing(fields.next()),
                declaration: try Fields.declaration(fields.next(), of: "value")
            )
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

    private func expression(_ value: Value) throws -> TypeExpression {
        var fields = try Fields(value, of: "type")
        let read: TypeExpression

        switch ObjectLayout.TypeTag(rawValue: try fields.tag()) {
        case .any: read = .any
        case .never: read = .never
        case .null: read = .null
        case .bool: read = .bool
        case .int: read = .int
        case .double: read = .double
        case .string: read = .string
        case .ranged: read = .ranged(try ranged(fields.next()))
        case .array: read = .array(try expression(fields.next()))
        case .dictionary: read = .dictionary(try expression(fields.next()))
        case .record: read = .record(try keyed(fields.next(), of: "record", expression))
        case .procedure:
            read = .procedure(
                try fields.maybe(procedureType),
                try constness(fields.next()),
                try isolation(fields.next())
            )

        case .variable: read = .variable(try expression(fields.next()))
        case .`inout`: read = .inout(try expression(fields.next()))
        case .linear: read = .linear(try expression(fields.next()))
        case .consuming: read = .consuming(try expression(fields.next()))
        case .borrowing: read = .borrowing(try expression(fields.next()))
        case .nullable: read = .nullable(try expression(fields.next()))
        case .named: read = .named(try name(fields.next()))
        case .parameter:
            read = .parameter(
                name: try name(fields.next()),
                constraints: try Fields.ordered(fields.next(), of: "bounds", name)
            )

        case .composition:
            let names = try Fields.ordered(fields.next(), of: "composition", name)

            guard !names.isEmpty else {
                throw ObjectRefused("'composition' joins nothing")
            }

            read = .composition(names)

        case .reading:
            read = .reading(
                of: try name(fields.next()),
                path: try path(fields.next())
            )

        case nil:
            throw ObjectRefused("'type' names a kind this reads none of")
        }

        try fields.end()

        return read
    }

    private func ranged(_ value: Value) throws -> TypeExpression.Refinement {
        var fields = try Fields(value, of: "range")
        let read: TypeExpression.Refinement

        switch ObjectLayout.RefinementTag(rawValue: try fields.tag()) {
        case .whole:
            read = .whole(
                from: try fields.maybe(integer),
                to: try fields.maybe { written in try edge(written, integer) }
            )

        case .fraction:
            read = .fraction(
                from: try fields.maybe(fraction),
                to: try fields.maybe { written in try edge(written, fraction) }
            )

        case nil:
            throw ObjectRefused("'range' is over neither whole numbers nor fractions")
        }

        try fields.end()

        return read
    }

    private func edge<Bound>(
        _ value: Value,
        _ read: (Value) throws -> Bound
    ) throws -> TypeExpression.Refinement.Edge<Bound> {
        var fields = try Fields(value, of: "edge")
        let held: TypeExpression.Refinement.Edge<Bound>

        switch ObjectLayout.EdgeTag(rawValue: try fields.tag()) {
        case .through: held = .through(try read(fields.next()))
        case .upTo: held = .upTo(try read(fields.next()))
        case nil: throw ObjectRefused("'edge' says neither that its bound is inside nor that it is out")
        }

        try fields.end()

        return held
    }

    private func counted(_ value: Value) throws -> Int {
        try Fields.count(value, of: "a count")
    }

    private func integer(_ value: Value) throws -> Int {
        try Fields.integer(value, of: "a number")
    }

    private func fraction(_ value: Value) throws -> Double {
        try Fields.double(value, of: "a fraction")
    }

    private func text(_ value: Value) throws -> String {
        try Fields.text(value, of: "a text")
    }

    private func path(_ value: Value) throws -> Path {
        Path(try Fields.list(value, of: "path", segment))
    }

    private func segment(_ value: Value) throws -> PathSegment {
        var fields = try Fields(value, of: "path segment")
        let read: PathSegment

        switch ObjectLayout.SegmentTag(rawValue: try fields.tag()) {
        case .key: read = .key(try name(fields.next()), optional: try fields.flag())
        case .index: read = .index(try fields.integer(), optional: try fields.flag())
        case .indexRef:
            read = .indexRef(
                try path(fields.next()),
                optional: try fields.flag()
            )

        case nil:
            throw ObjectRefused("'path segment' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }

    private func contractProcedure(_ value: Value) throws -> ContractProcedure {
        var fields = try Fields(value, of: "contract procedure")
        let read = ContractProcedure(
            signature: try signature(fields.next()),
            constness: try constness(fields.next()),
            isolation: try isolation(fields.next())
        )

        try fields.end()

        return read
    }

    private func procedureType(_ value: Value) throws -> ProcedureType {
        var fields = try Fields(value, of: "procedure type")
        let read = ProcedureType(
            parameters: try Fields.list(fields.next(), of: "parameters", expression),
            returns: try fields.maybe(expression)
        )

        try fields.end()

        return read
    }

    private func signature(_ value: Value) throws -> Signature {
        var fields = try Fields(value, of: "signature")
        let read = Signature(
            parameters: try Fields.list(fields.next(), of: "parameters", parameter),
            returns: try fields.maybe(expression)
        )

        try fields.end()

        return read
    }

    private func parameter(_ value: Value) throws -> Parameter {
        var fields = try Fields(value, of: "parameter")
        let read = Parameter(
            name: try name(fields.next()),
            type: try fields.maybe(expression),
            candidates: try fields.maybe { written in try Fields.list(written, of: "candidates", text) },
            description: try fields.maybe(text)
        )

        try fields.end()

        return read
    }

    private func access(_ value: Value) throws -> Access {
        switch ObjectLayout.AccessTag(rawValue: try integer(value)) {
        case .`private`: return .private
        case .`internal`: return .internal
        case .`public`: return .public
        case nil: throw ObjectRefused("'access' says none of private, internal and public")
        }
    }

    private func constness(_ value: Value) throws -> Constness {
        switch ObjectLayout.ConstnessTag(rawValue: try integer(value)) {
        case .unstated: return .unstated
        case .const: return .const
        case nil: throw ObjectRefused("'constness' says neither that it is stated nor that it is const")
        }
    }

    private func isolation(_ value: Value) throws -> Isolation {
        switch ObjectLayout.IsolationTag(rawValue: try integer(value)) {
        case .unstated: return .unstated
        case .isolated: return .isolated
        case nil: throw ObjectRefused("'isolation' says neither that it is stated nor that it is isolated")
        }
    }

    private func failing(_ value: Value) throws -> Failing {
        var fields = try Fields(value, of: "failing")
        let read: Failing

        switch ObjectLayout.FailingTag(rawValue: try fields.tag()) {
        case .unstated: read = .unstated
        case .these:
            read = .these(Set(try Fields.ordered(fields.next(), of: "failing", text)))
        case nil: throw ObjectRefused("'failing' says neither nothing nor which failures")
        }

        try fields.end()

        return read
    }

    private func place(_ value: Value) throws -> Place {
        var fields = try Fields(value, of: "place")
        let stands = try held(fields.next())
        let read = Place(try Fields.list(fields.next(), of: "place", step), in: stands)

        try fields.end()

        return read
    }

    private func step(_ value: Value) throws -> Place.Step {
        var fields = try Fields(value, of: "place step")
        let read: Place.Step

        switch ObjectLayout.PlaceStepTag(rawValue: try fields.tag()) {
        case .key: read = .key(try fields.text())
        case .part: read = .part(try part(fields.next()))
        case .construct: read = .construct(try construct(fields.next()))
        case .index: read = .index(try fields.integer())
        case .statement: read = .statement(name: try fields.maybe(text), at: try fields.integer())
        case .landmark: read = .landmark(try fields.text())
        case nil: throw ObjectRefused("'place step' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }

    private func part(_ value: Value) throws -> Place.Part {
        var fields = try Fields(value, of: "part")
        let read: Place.Part

        switch ObjectLayout.PartTag(rawValue: try fields.tag()) {
        case .procedures: read = .procedures
        case .constants: read = .constants
        case .variables: read = .variables
        case .types: read = .types
        case .constraints: read = .constraints
        case .contracts: read = .contracts
        case .satisfies: read = .satisfies
        case .imports: read = .imports
        case .parameters: read = .parameters
        case .returns: read = .returns
        case .body: read = .body
        case .result: read = .result
        case .subject:
            guard case let .bool(optional) = try fields.next() else {
                throw ObjectRefused("'part' names a cast's subject without saying whether the cast reads a mismatch as null")
            }

            read = .subject(optional: optional)
        case .callee: read = .callee
        case .arguments: read = .arguments
        case .closure: read = .closure
        case .condition: read = .condition(of: try holder(fields.next()))
        case .then: read = .then
        case .otherwise: read = .otherwise
        case .rescue: read = .rescue
        case .fields: read = .fields
        case nil: throw ObjectRefused("'part' names a part this reads none of")
        }

        try fields.end()

        return read
    }

    private func holder(_ value: Value) throws -> Place.ConditionHolder {
        var fields = try Fields(value, of: "condition holder")
        let read: Place.ConditionHolder

        switch ObjectLayout.ConditionHolderTag(rawValue: try fields.tag()) {
        case .conditional: read = .conditional
        case .loop: read = .loop
        case nil: throw ObjectRefused("'condition holder' holds a condition in no way this reads")
        }

        try fields.end()

        return read
    }

    private func construct(_ value: Value) throws -> Construct {
        var fields = try Fields(value, of: "construct")
        let read: Construct

        switch ObjectLayout.ConstructTag(rawValue: try fields.tag()) {
        case .literal: read = .literal
        case .reference: read = .reference
        case .array: read = .array
        case .record: read = .record
        case .closure: read = .closure
        case .cast: read = .cast
        case .block: read = .block
        case .conditional: read = .conditional
        case .loop: read = .loop
        case .attempt: read = .attempt
        case .call: read = .call
        case .leave: read = .leave(try reach(fields.next()))
        case nil: throw ObjectRefused("'construct' names a construct this reads none of")
        }

        try fields.end()

        return read
    }

    private func reach(_ value: Value) throws -> Leave.Reach {
        switch ObjectLayout.ReachTag(rawValue: try integer(value)) {
        case .procedure: return .procedure
        case .construct: return .construct
        case .round: return .round
        case nil: throw ObjectRefused("'leave' reaches nothing this reads")
        }
    }

    private func layout(_ value: Value) throws -> Layout {
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

    private func lowered(_ value: Value) throws -> LoweredType {
        var fields = try Fields(value, of: "lowered type")
        let read: LoweredType

        switch ObjectLayout.LoweredTypeTag(rawValue: try fields.tag()) {
        case .any: read = .any
        case .never: read = .never
        case .null: read = .null
        case .bool: read = .bool
        case .int: read = .int
        case .double: read = .double
        case .string: read = .string
        case .ranged: read = .ranged(try ranged(fields.next()))
        case .array: read = .array(try lowered(fields.next()))
        case .dictionary: read = .dictionary(try lowered(fields.next()))
        case .record: read = .record(try loweredRecord(fields.next()))
        case .procedure:
            read = .procedure(
                parameters: try fields.maybe { written in
                    try Fields.list(written, of: "parameters", lowered)
                },
                returns: try fields.maybe(lowered),
                constness: try constness(fields.next()),
                isolation: try isolation(fields.next())
            )

        case .variable: read = .variable(try lowered(fields.next()))
        case .`inout`: read = .inout(try lowered(fields.next()))
        case .nullable: read = .nullable(try lowered(fields.next()))
        case .named: read = .named(try fields.count())
        case .parameter:
            read = .parameter(label: try name(fields.next()), bounds: try Fields.ordered(fields.next(), of: "bounds", bound))

        case .composition:
            let bounds = try Fields.ordered(fields.next(), of: "composition", bound)

            guard !bounds.isEmpty else {
                throw ObjectRefused("'composition' holds a value to nothing")
            }

            read = .composition(bounds)

        case .reading:
            read = .reading(
                of: try name(fields.next()),
                path: try path(fields.next())
            )

        case .undeclared: read = .undeclared(label: try fields.text(), because: try undeclared(fields.next()))
        case nil: throw ObjectRefused("'lowered type' names a kind this reads none of")
        }

        try fields.end()

        return read
    }

    private func undeclared(_ value: Value) throws -> LoweredType.Undeclared {
        var fields = try Fields(value, of: "undeclared")
        let read: LoweredType.Undeclared

        switch ObjectLayout.UndeclaredTag(rawValue: try fields.tag()) {
        case .noTypeNamed: read = .noTypeNamed(try name(fields.next()))
        case .noBoundNamed: read = .noBoundNamed(try name(fields.next()))
        case .namesItself: read = .namesItself
        case nil: throw ObjectRefused("'undeclared' is undeclared for a reason this reads none of")
        }

        try fields.end()

        return read
    }

    private func bound(_ value: Value) throws -> LoweredType.Bound {
        var fields = try Fields(value, of: "bound")
        let read: LoweredType.Bound

        switch ObjectLayout.BoundTag(rawValue: try fields.tag()) {
        case .membership: read = .membership(try fields.count())
        case .contract: read = .contract(try name(fields.next()))
        case nil: throw ObjectRefused("'bound' holds a parameter to nothing this reads")
        }

        try fields.end()

        return read
    }

    private func loweredRecord(_ value: Value) throws -> LoweredRecord {
        var fields = try Fields(value, of: "record")
        let held = try layout(fields.next())
        let read = try LoweredRecord(
            layout: held,
            judging: try Fields.list(fields.next(), of: "record", lowered)
        )

        try fields.end()

        return read
    }

    // A declared row carries its spelling; a lifted row is handed the one
    // its numbering answers.
    private func judged(_ value: Value, spelled: Name?) throws -> Judged {
        var fields = try Fields(value, of: "row")
        let label = try spelled ?? name(fields.next())
        let signature = try signature(fields.next())
        let read = try Judged(
            label: label,
            signature: signature,
            access: try access(fields.next()),
            constness: try constness(fields.next()),
            isolation: try isolation(fields.next()),
            failing: try failing(fields.next()),
            sends: try Fields.list(fields.next(), of: "row", sent),
            judging: try implementation(fields.next())
        )

        try fields.end()

        return read
    }

    private func implementation(_ value: Value) throws -> Judged.Implementation {
        var fields = try Fields(value, of: "implementation")
        let read: Judged.Implementation

        switch ObjectLayout.ImplementationTag(rawValue: try fields.tag()) {
        case .body: read = .body(try body(fields.next()), try frame(fields.next()))

        case .native: read = .native(sending: try Fields.list(fields.next(), of: "sending", send))
        case nil: throw ObjectRefused("'implementation' answers in a way this reads none of")
        }

        try fields.end()

        return read
    }

    private func sent(_ value: Value) throws -> Sent {
        var fields = try Fields(value, of: "send")
        let read = Sent(
            row: try fields.count(),
            handing: try fields.count()
        )

        try fields.end()

        return read
    }

    private func send(_ value: Value) throws -> Native.Send {
        var fields = try Fields(value, of: "native send")
        let read = Native.Send(
            position: try fields.count(),
            selector: try name(fields.next()),
            handing: try fields.count()
        )

        try fields.end()

        return read
    }

    private func frame(_ value: Value) throws -> Frame {
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

    private func body(_ value: Value) throws -> LoweredBody {
        var fields = try Fields(value, of: "body")
        let read = LoweredBody(
            instructions: try Fields.list(fields.next(), of: "body", instruction),
            result: try fields.maybe(operation)
        )

        try fields.end()

        return read
    }

    private func instruction(_ value: Value) throws -> Instruction {
        var fields = try Fields(value, of: "instruction")
        let read = Instruction(
            binding: try fields.maybe(binding),
            code: try operation(fields.next()),
            label: try fields.text()
        )

        try fields.end()

        return read
    }

    private func binding(_ value: Value) throws -> Instruction.Binding {
        var fields = try Fields(value, of: "binding")
        let read: Instruction.Binding

        switch ObjectLayout.BindingTag(rawValue: try fields.tag()) {
        case .bind: read = .bind(try fields.count(), settling: try fields.maybe(lowered))
        case .declare: read = .declare(try fields.count(), settling: try fields.maybe(lowered))
        case .assign: read = .assign(try address(fields.next()), settling: try fields.maybe(lowered))
        case nil: throw ObjectRefused("'binding' binds in a way this reads none of")
        }

        try fields.end()

        return read
    }

    private func address(_ value: Value) throws -> Address {
        var fields = try Fields(value, of: "address")
        let read = Address(
            slot: try fields.count(),
            steps: try Fields.list(fields.next(), of: "address", walk)
        )

        try fields.end()

        return read
    }

    private func walk(_ value: Value) throws -> Step {
        var fields = try Fields(value, of: "walk")
        let read: Step

        switch ObjectLayout.StepTag(rawValue: try fields.tag()) {
        case .field:
            read = .field(try fields.count(), try name(fields.next()), optional: try fields.flag())

        case .key: read = .key(try name(fields.next()), optional: try fields.flag())
        case .index: read = .index(try fields.integer(), optional: try fields.flag())
        case .at: read = .at(try address(fields.next()), optional: try fields.flag())
        case nil: throw ObjectRefused("'walk' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }

    private func operation(_ value: Value) throws -> Operation {
        var fields = try Fields(value, of: "operation")
        let read: Operation

        switch ObjectLayout.OperationTag(rawValue: try fields.tag()) {
        case .literal: read = .literal(try self.value(fields.next()))
        case .local: read = .local(try address(fields.next()))
        case .array: read = .array(try Fields.list(fields.next(), of: "array", operation))
        case .record: read = .record(try recordOperation(fields.next()))
        case .closure:
            read = .closure(
                try fields.count(),
                captures: try Fields.list(fields.next(), of: "captures") { written in
                    var held = try Fields(written, of: "capture")
                    let taken = (try held.count(), try held.count())

                    try held.end()

                    return taken
                }
            )

        case .apply:
            read = .apply(
                try operation(fields.next()),
                arguments: try Fields.list(fields.next(), of: "arguments", operation)
            )

        case .cast:
            read = .cast(
                try operation(fields.next()),
                as: try lowered(fields.next()),
                optional: try fields.flag()
            )

        case .block: read = .block(try body(fields.next()))
        case .conditional:
            read = .conditional(
                try operation(fields.next()),
                then: try Fields.list(fields.next(), of: "then", instruction),
                else: try fields.maybe { written in
                    try Fields.list(written, of: "otherwise", instruction)
                }
            )

        case .loop:
            read = .loop(
                while: try operation(fields.next()),
                body: try body(fields.next()),
                round: try fields.maybe(counted),
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

        case .attempt:
            read = .attempt(
                try body(fields.next()),
                rescue: try body(fields.next()),
                failure: try fields.maybe(counted)
            )

        case .call: read = .call(try callOperation(fields.next()))
        case .dispatch: read = .dispatch(try dispatchOperation(fields.next()))
        case .leave:
            read = .leave(
                try reach(fields.next()),
                target: try fields.maybe(name),
                try fields.maybe(operation)
            )

        case nil:
            throw ObjectRefused("'operation' does something this reads none of")
        }

        try fields.end()

        return read
    }

    private func recordOperation(_ value: Value) throws -> RecordOperation {
        var fields = try Fields(value, of: "record")
        let held = try layout(fields.next())
        let read = try RecordOperation(
            layout: held,
            judging: try Fields.list(fields.next(), of: "record", operation)
        )

        try fields.end()

        return read
    }

    private func callOperation(_ value: Value) throws -> CallOperation {
        var fields = try Fields(value, of: "call")
        let read = try CallOperation(
            procedure: try fields.count(),
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

    private func dispatchOperation(_ value: Value) throws -> DispatchOperation {
        var fields = try Fields(value, of: "dispatch")
        let read = DispatchOperation(
            contract: try name(fields.next()),
            procedure: try name(fields.next()),
            first: try operation(fields.next()),
            arguments: try Fields.list(fields.next(), of: "arguments", argument)
        )

        try fields.end()

        return read
    }

    private func argument(_ value: Value) throws -> Argument {
        var fields = try Fields(value, of: "argument")
        let read: Argument

        switch ObjectLayout.ArgumentTag(rawValue: try fields.tag()) {
        case .value: read = .value(try operation(fields.next()))
        case .reference: read = .reference(try address(fields.next()))
        case nil: throw ObjectRefused("'argument' is handed in a way this reads none of")
        }

        try fields.end()

        return read
    }
}
