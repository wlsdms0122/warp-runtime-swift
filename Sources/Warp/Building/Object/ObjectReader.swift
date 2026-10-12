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

    // MARK: - Initializer
    init(of identity: Identity?) {
        self.identity = identity
    }

    // MARK: - Public
    func compiled(from value: Value) throws -> Compiled {
        guard case let .dictionary(map) = value else {
            throw ObjectRefused("'object' is not written as a map")
        }

        // A document says `warp` where an object says `object`, and one handed
        // here is refused for what it is.
        if map[Module.versionKey] != nil {
            throw ObjectRefused("this is a document, and not an object")
        }

        // The layout first, and before anything laid out by it, the keys
        // included: what this number says is whether the rest of the map
        // means what this reading takes it to mean.
        guard let stamped = map[ObjectLayout.Key.object.name] else {
            throw ObjectRefused("'object' writes no '\(ObjectLayout.Key.object.name)'")
        }

        let format = try Field(stamped, of: "object").count()

        guard format == ObjectLayout.format else {
            throw ObjectRefused(
                "the object is laid out as format \(format), and this reads format \(ObjectLayout.format)"
            )
        }

        // Every part read by the one case that names its key, so a key the
        // layout gains is a case this has to read. The rows the document
        // declares are what the numbering counts from, and the numbering spells
        // the rows its bodies lifted, so those two are kept as written until
        // every part is in.
        var dependencies: [Fingerprint] = []
        var types: [Name: TypeDeclaration] = [:]
        var contracts: [Name: [Name: ContractProcedure]] = [:]
        var claims: [Name: Set<Name>] = [:]
        var leaned: [Claim: Place] = [:]
        var declaredRows: [Judged] = []
        var liftedRows: [Value] = []
        var answers: [Name: LoweredType] = [:]
        var numbered: Value = .null
        var typeNumbering = LoweredTypeNumbering(types: [])
        var variables: [(name: Name, value: Value)] = []
        var constants: [Name] = []

        for (key, part) in try Keyed(map).parts {
            switch key {
            // Read above, before the map is held to the layout.
            case .object:
                continue

            case .document:
                try refuseAnotherDocument(part)

            case .dependencies:
                dependencies = try Field(part, of: "dependencies").ordered { written in
                    Fingerprint(try Field(written, of: "dependencies").bytes())
                }

            // Held where they are read to the rule a document's are held to
            // at the load, so no lowering meets a name coming back to itself.
            case .types:
                types = try keyed(part, of: "types", declaration)

                if let name = types.keys.sorted().first(where: { name in Validator().comesBack(name, in: types) }) {
                    throw ObjectRefused("'\(name)' \(Validator.comingBack)")
                }

            case .contracts:
                contracts = try keyed(part, of: "contracts") { written in
                    try keyed(written, of: "contract", contractProcedure)
                }

            case .claims:
                claims = try keyed(part, of: "claims") { written in
                    Set(try Field(written, of: "claims").ordered(name))
                }

            case .leaned:
                leaned = try self.leaned(part)

            // The rows the document declares stand under their spellings.
            case .rows:
                declaredRows = try Field(part, of: "rows").list { written in
                    try judged(written, spelled: nil)
                }

            case .lifted:
                liftedRows = try Field(part, of: "lifted").list { written in written }

            case .answers:
                answers = try keyed(part, of: "answers", lowered)

            // What the document sends and how many closures each declaration
            // wrote, which is what its bodies number their calls from.
            case .numbering:
                numbered = part

            // The types its bodies stand on, which is what they number their
            // types from.
            case .typeNumbering:
                typeNumbering = try LoweredTypeNumbering(written: part)

            case .variables:
                variables = try Field(part, of: "variables").led(variable)

            case .constants:
                constants = try Field(part, of: "constants").ordered(name)
            }
        }

        let declared = declaredRows.map(\.label)

        // One row per spelling, in name order: what the numbering counts
        // from and what a link looks a spelling up in both stand on it.
        guard declared.ordered else {
            throw ObjectRefused("the declared rows stand out of name order, or one spelling stands twice")
        }

        let numbering = try Numbering(written: numbered, declaring: declared)
        let table = declaredRows + (try liftedRows.enumerated().map { index, written in
            guard let writer = numbering.writer(of: index) else {
                throw ObjectRefused("a lifted row stands where the numbering counts no closure")
            }

            return try judged(written, spelled: writer.by.name)
        })

        return try Compiled(
            document: Place.Document(identity: identity),
            types: types,
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
            dependencies: dependencies
        )
    }

    // A value as the writing laid it down: data as it is, and a closure by
    // what it is spelled by, standing without a row until a link answers one.
    func value(_ value: Value) throws -> Value {
        var cursor = try FieldCursor(value, of: "value")
        let read: Value

        switch ObjectLayout.ValueTag(rawValue: try cursor.field().integer()) {
        case .null: read = .null
        case .bool:
            guard case let .bool(held) = try cursor.next() else {
                throw ObjectRefused("'value' writes something other than a bool where one stands")
            }

            read = .bool(held)

        case .int: read = .int(try cursor.field().integer())
        case .double: read = .double(try cursor.field().double())
        case .string: read = .string(try cursor.field().text())
        case .bytes: read = .bytes(try cursor.field().bytes())
        case .array: read = .array(try cursor.field().list(self.value))

        // A value the model refuses is one the writing could not have laid
        // down, and so one this reading refuses as an object.
        case .record:
            let named = try name(cursor.next())
            let names = try cursor.field().list(name)
            let values = try cursor.field().list(self.value)

            read = try refusing {
                .record(try Record(layout: try Layout(name: named, judging: names), checking: values))
            }

        // The keys in the key order, none the same as another, which is how
        // the writing lays a map down.
        case .dictionary:
            let keys = try cursor.field().list(self.value)
            let values = try cursor.field().list(self.value)

            guard
                keys.count == values.count,
                zip(keys, keys.dropFirst()).allSatisfy({ one, other in Value.Dictionary.order(one, other) == .orderedAscending })
            else {
                throw ObjectRefused("'map' writes its keys out of the key order, one twice, or another count than its values")
            }

            read = .dictionary(Value.Dictionary(ordered: Array(zip(keys, values)).map { key, value in (key: key, value: value) }))

        case .closure:
            let writer = Closure.Writer(
                document: try writing(cursor.next()),
                declaration: try cursor.field().declaration()
            )
            let nth = try cursor.field().count()
            let captured = try cursor.field().list { cell -> (slot: Int, cell: Cell) in
                var cursor = try FieldCursor(cell, of: "captured")
                let read = (slot: try cursor.field().count(), cell: Cell.value(try self.value(cursor.next())))

                try cursor.end()

                return read
            }

            read = .procedure(Closure(writer: writer, nth: nth, linked: nil, captured: captured))

        case nil: throw ObjectRefused("'value' answers in a way this reads none of")
        }

        try cursor.end()

        return read
    }

    // MARK: - Private
    private func keyed<T>(
        _ value: Value,
        of part: String,
        _ read: (Value) throws -> T
    ) throws -> [Name: T] {
        try Field(value, of: part).gathered { entry in
            var cursor = try FieldCursor(entry, of: part)
            let held = (try cursor.field().name(), try read(cursor.next()))

            try cursor.end()

            return held
        }
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
        try Field(value, of: "a name").name()
    }

    // The document an object says it is of, held to the one it was kept
    // under.
    private func refuseAnotherDocument(_ value: Value) throws {
        let read = try Field(value, of: "document").maybe { written in
            Identity(try Field(written, of: "document").bytes())
        }

        guard read == identity else {
            throw ObjectRefused(
                "this object stands against a document other than the one it was kept under"
            )
        }
    }

    // The document a closure's writer stands in, which may be another
    // document's: a closure a fold settled came out of whatever the fold ran.
    // The writing spells no document nobody wrote down, so a writer with
    // none is one the writing never laid down.
    private func writing(_ value: Value) throws -> Closure.Document {
        .written(Identity(try Field(value, of: "writer").bytes()))
    }

    // The document a place inside this object is an address in.
    private func held(_ value: Value) throws -> Place.Document {
        Place.Document(
            identity: try Field(value, of: "place document").maybe { written in
                Identity(try Field(written, of: "place document").bytes())
            }
        )
    }

    private func leaned(_ value: Value) throws -> [Claim: Place] {
        try Field(value, of: "leaned").gathered { entry in
            var cursor = try FieldCursor(entry, of: "leaned")
            let claim = Claim(type: try name(cursor.next()), contract: try name(cursor.next()))
            let place = try place(cursor.next())

            try cursor.end()

            return (claim, place)
        }
    }

    private func variable(_ value: Value) throws -> (name: Name, value: Value) {
        var cursor = try FieldCursor(value, of: "variable")
        let read = (name: try name(cursor.next()), value: try self.value(cursor.next()))

        try cursor.end()

        return read
    }

    // A declared type: a record, its fields under the record's tag, or the
    // type an alias stands for.
    private func declaration(_ value: Value) throws -> TypeDeclaration {
        var cursor = try FieldCursor(value, of: "type")

        guard ObjectLayout.TypeTag(rawValue: try cursor.field().integer()) == .record else {
            return .alias(try expression(value))
        }

        let fields = try keyed(cursor.next(), of: "record", expression)

        try cursor.end()

        return .record(fields)
    }

    private func expression(_ value: Value) throws -> TypeExpression {
        var cursor = try FieldCursor(value, of: "type")
        let read: TypeExpression

        switch ObjectLayout.TypeTag(rawValue: try cursor.field().integer()) {
        case .any: read = .any
        case .never: read = .never
        case .null: read = .null
        case .bool: read = .bool
        case .int: read = .int
        case .double: read = .double
        case .string: read = .string
        case .array: read = .array(try expression(cursor.next()))
        case .dictionary: read = .dictionary(key: try expression(cursor.next()), value: try expression(cursor.next()))
        // A record type is written once, as a declared type's own.
        case .record: throw ObjectRefused("'type' writes a record, which stands only as a type a document declares")
        case .procedure:
            read = .procedure(
                try cursor.field().maybe(procedureType),
                try constness(cursor.next()),
                try isolation(cursor.next())
            )

        case .variable: read = .variable(try expression(cursor.next()))
        case .`inout`: read = .inout(try expression(cursor.next()))
        case .nullable: read = .nullable(try expression(cursor.next()))
        case .named: read = .named(try name(cursor.next()))
        case .parameter: read = .parameter(name: try name(cursor.next()))

        // One contract is written by its name, so a composition joins two
        // or more, the way a document's does.
        case .composition:
            let names = try Field(cursor.next(), of: "composition").ordered(name)

            guard names.count > 1 else {
                throw ObjectRefused("'composition' joins fewer than two names, and one is written as the name")
            }

            read = .composition(Set(names))

        case .projection:
            read = .projection(
                of: try name(cursor.next()),
                path: try path(cursor.next())
            )

        case .selfType:
            read = .selfType

        case nil:
            throw ObjectRefused("'type' names a kind this reads none of")
        }

        try cursor.end()

        return read
    }

    private func counted(_ value: Value) throws -> Int {
        try Field(value, of: "a count").count()
    }

    private func integer(_ value: Value) throws -> Int {
        try Field(value, of: "a number").integer()
    }

    private func text(_ value: Value) throws -> String {
        try Field(value, of: "a text").text()
    }

    private func path(_ value: Value) throws -> Path {
        Path(try Field(value, of: "path").list(segment))
    }

    private func segment(_ value: Value) throws -> PathSegment {
        var cursor = try FieldCursor(value, of: "path segment")
        let read: PathSegment

        switch ObjectLayout.SegmentTag(rawValue: try cursor.field().integer()) {
        case .name: read = .name(try name(cursor.next()), optional: try cursor.field().flag())
        case .index: read = .index(try self.value(cursor.next()), optional: try cursor.field().flag())
        case .indexRef:
            read = .indexRef(
                try path(cursor.next()),
                optional: try cursor.field().flag()
            )

        case nil:
            throw ObjectRefused("'path segment' steps in a way this reads none of")
        }

        try cursor.end()

        return read
    }

    private func contractProcedure(_ value: Value) throws -> ContractProcedure {
        var cursor = try FieldCursor(value, of: "contract procedure")
        let signature = try signature(cursor.next())
        let constness = try constness(cursor.next())
        let isolation = try isolation(cursor.next())

        // A contract's procedure names what it may fail with, nothing
        // included.
        guard case let .these(failing) = try failing(cursor.next()) else {
            throw ObjectRefused("a contract's procedure's 'failing' says which failures")
        }

        let read = ContractProcedure(signature: signature, constness: constness, isolation: isolation, failing: failing)

        try cursor.end()

        return read
    }

    private func procedureType(_ value: Value) throws -> ProcedureType {
        var cursor = try FieldCursor(value, of: "procedure type")
        let read = ProcedureType(
            parameters: try Field(cursor.next(), of: "parameters").list(expression),
            returns: try cursor.field().maybe(expression)
        )

        try cursor.end()

        return read
    }

    private func signature(_ value: Value) throws -> Signature {
        var cursor = try FieldCursor(value, of: "signature")
        let read = Signature(
            parameters: try Field(cursor.next(), of: "parameters").list(parameter),
            returns: try cursor.field().maybe(expression),
            bounds: try keyed(cursor.next(), of: "bounds") { written in
                let contracts = try Field(written, of: "bounds").ordered(name)

                guard !contracts.isEmpty else {
                    throw ObjectRefused("'bounds' holds a type parameter to nothing")
                }

                return Set(contracts)
            }
        )

        try cursor.end()

        return read
    }

    // A parameter taking anything writes no type, so a written `Any` is a
    // second writing of one signature.
    private func parameter(_ value: Value) throws -> Parameter {
        var cursor = try FieldCursor(value, of: "parameter")
        let name = try name(cursor.next())
        let type = try cursor.field().maybe(expression)

        guard type != .any else {
            throw ObjectRefused("a parameter taking anything writes no type")
        }

        let read = Parameter(name: name, type: type ?? .any, description: try cursor.field().maybe(text))

        try cursor.end()

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
        var cursor = try FieldCursor(value, of: "failing")
        let read: Failing

        switch ObjectLayout.FailingTag(rawValue: try cursor.field().integer()) {
        case .unstated: read = .unstated
        case .these:
            read = .these(Set(try cursor.field().ordered(text)))
        case nil: throw ObjectRefused("'failing' says neither nothing nor which failures")
        }

        try cursor.end()

        return read
    }

    private func place(_ value: Value) throws -> Place {
        var cursor = try FieldCursor(value, of: "place")
        let stands = try held(cursor.next())
        let read = Place(try cursor.field().list(step), in: stands)

        try cursor.end()

        return read
    }

    private func step(_ value: Value) throws -> Place.Step {
        var cursor = try FieldCursor(value, of: "place step")
        let read: Place.Step

        switch ObjectLayout.PlaceStepTag(rawValue: try cursor.field().integer()) {
        case .key: read = .key(try cursor.field().text())
        case .part: read = .part(try part(cursor.next()))
        case .construct: read = .construct(try construct(cursor.next()))
        case .index: read = .index(try cursor.field().integer())
        case .statement: read = .statement(name: try cursor.field().maybe(text), at: try cursor.field().integer())
        case .landmark: read = .landmark(try cursor.field().text())
        case nil: throw ObjectRefused("'place step' steps in a way this reads none of")
        }

        try cursor.end()

        return read
    }

    private func part(_ value: Value) throws -> Place.Part {
        var cursor = try FieldCursor(value, of: "part")
        let read: Place.Part

        switch ObjectLayout.PartTag(rawValue: try cursor.field().integer()) {
        case .procedures: read = .procedures
        case .constants: read = .constants
        case .variables: read = .variables
        case .types: read = .types
        case .contracts: read = .contracts
        case .satisfies: read = .satisfies
        case .imports: read = .imports
        case .parameters: read = .parameters
        case .returns: read = .returns
        case .body: read = .body
        case .result: read = .result
        case .subject:
            guard case let .bool(optional) = try cursor.next() else {
                throw ObjectRefused(
                    "'part' names a cast's subject without saying whether the cast reads a mismatch as null"
                )
            }

            read = .subject(optional: optional)
        case .callee: read = .callee
        case .arguments: read = .arguments
        case .closure: read = .closure
        case .condition: read = .condition(of: try holder(cursor.next()))
        case .then: read = .then
        case .otherwise: read = .otherwise
        case .rescue: read = .rescue
        case .fields: read = .fields
        case .bounds: read = .bounds
        case .entries: read = .entries
        case nil: throw ObjectRefused("'part' names a part this reads none of")
        }

        try cursor.end()

        return read
    }

    private func holder(_ value: Value) throws -> Place.ConditionHolder {
        var cursor = try FieldCursor(value, of: "condition holder")
        let read: Place.ConditionHolder

        switch ObjectLayout.ConditionHolderTag(rawValue: try cursor.field().integer()) {
        case .conditional: read = .conditional
        case .loop: read = .loop
        case nil: throw ObjectRefused("'condition holder' holds a condition in no way this reads")
        }

        try cursor.end()

        return read
    }

    private func construct(_ value: Value) throws -> Construct {
        var cursor = try FieldCursor(value, of: "construct")
        let read: Construct

        switch ObjectLayout.ConstructTag(rawValue: try cursor.field().integer()) {
        case .literal: read = .literal
        case .reference: read = .reference
        case .array: read = .array
        case .record: read = .record
        case .dictionary: read = .dictionary
        case .closure: read = .closure
        case .cast: read = .cast
        case .block: read = .block
        case .conditional: read = .conditional
        case .loop: read = .loop
        case .attempt: read = .attempt
        case .call: read = .call
        case .leave: read = .leave(try reach(cursor.next()))
        case nil: throw ObjectRefused("'construct' names a construct this reads none of")
        }

        try cursor.end()

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
        var cursor = try FieldCursor(value, of: "layout")
        let named = try name(cursor.next())
        let written = try cursor.field().list(name)

        try cursor.end()

        // Through the door that judges rather than the one that orders. What
        // stands beside a layout here is a list of values read on its own, and
        // a reading that put the names in order would pair them with values
        // that never moved.
        return try refusing { try Layout(name: named, judging: written) }
    }

    private func lowered(_ value: Value) throws -> LoweredType {
        var cursor = try FieldCursor(value, of: "lowered type")
        let read: LoweredType

        switch ObjectLayout.LoweredTypeTag(rawValue: try cursor.field().integer()) {
        case .any: read = .any
        case .never: read = .never
        case .null: read = .null
        case .bool: read = .bool
        case .int: read = .int
        case .double: read = .double
        case .string: read = .string
        case .array: read = .array(try lowered(cursor.next()))
        case .dictionary: read = .dictionary(key: try lowered(cursor.next()), value: try lowered(cursor.next()))
        // A type that writes no parameters writes no signature, so it says
        // nothing of an answer either.
        case .procedure:
            let parameters = try cursor.field().maybe { written in
                try Field(written, of: "parameters").list(lowered)
            }
            let returns = try cursor.field().maybe(lowered)

            guard parameters != nil || returns == nil else {
                throw ObjectRefused("a procedure type writes what it answers and nothing of what it takes")
            }

            read = .procedure(
                parameters.map { parameters in LoweredProcedureType(parameters: parameters, returns: returns) },
                constness: try constness(cursor.next()),
                isolation: try isolation(cursor.next())
            )

        case .variable: read = .variable(try lowered(cursor.next()))
        case .`inout`: read = .inout(try lowered(cursor.next()))
        case .nullable: read = .nullable(try lowered(cursor.next()))
        case .named: read = .named(try cursor.field().count())
        case .parameter:
            read = .parameter(
                label: try name(cursor.next()),
                bounds: try Field(cursor.next(), of: "bounds").ordered(name)
            )

        case .composition:
            let bounds = try Field(cursor.next(), of: "composition").ordered(name)

            guard !bounds.isEmpty else {
                throw ObjectRefused("'composition' holds a value to nothing")
            }

            read = .composition(bounds)

        case .projection:
            read = .projection(
                of: try name(cursor.next()),
                path: try path(cursor.next())
            )

        case nil: throw ObjectRefused("'lowered type' names a kind this reads none of")
        }

        try cursor.end()

        return read
    }

    // A declared row carries its spelling; a lifted row is handed the one
    // its numbering answers.
    private func judged(_ value: Value, spelled: Name?) throws -> Judged {
        var cursor = try FieldCursor(value, of: "row")
        let label = try spelled ?? name(cursor.next())
        let signature = try signature(cursor.next())
        let read = try Judged(
            label: label,
            signature: signature,
            access: try access(cursor.next()),
            constness: try constness(cursor.next()),
            isolation: try isolation(cursor.next()),
            failing: try failing(cursor.next()),
            judging: try implementation(cursor.next())
        )

        try cursor.end()

        return read
    }

    private func implementation(_ value: Value) throws -> Judged.Implementation {
        var cursor = try FieldCursor(value, of: "implementation")
        let read: Judged.Implementation

        switch ObjectLayout.ImplementationTag(rawValue: try cursor.field().integer()) {
        case .body: read = .body(try body(cursor.next()), try frame(cursor.next()))

        case .native: read = .native(sending: try Field(cursor.next(), of: "sending").list(send))
        case nil: throw ObjectRefused("'implementation' answers in a way this reads none of")
        }

        try cursor.end()

        return read
    }

    private func send(_ value: Value) throws -> Native.Send {
        var cursor = try FieldCursor(value, of: "native send")
        let read = Native.Send(
            position: try cursor.field().count(),
            selector: try name(cursor.next()),
            handing: try cursor.field().count()
        )

        try cursor.end()

        return read
    }

    private func frame(_ value: Value) throws -> Frame {
        var cursor = try FieldCursor(value, of: "frame")
        let size = try cursor.field().count()
        let read = Frame(
            size: size,
            parameters: try cursor.field().list(counted),
            variables: try cursor.field().list { written in
                var held = try FieldCursor(written, of: "frame variable")
                let taken = (variable: try held.field().count(), slot: try held.field().count())

                try held.end()

                return taken
            },
            captures: try cursor.field().list(counted),
            names: try cursor.field().list(name)
        )

        try cursor.end()

        return read
    }

    private func body(_ value: Value) throws -> LoweredBody {
        var cursor = try FieldCursor(value, of: "body")
        let read = LoweredBody(
            instructions: try cursor.field().list(instruction),
            result: try cursor.field().maybe(operation)
        )

        try cursor.end()

        return read
    }

    private func instruction(_ value: Value) throws -> Instruction {
        var cursor = try FieldCursor(value, of: "instruction")
        let read = Instruction(
            binding: try cursor.field().maybe(binding),
            code: try operation(cursor.next()),
            label: try cursor.field().text()
        )

        try cursor.end()

        return read
    }

    private func binding(_ value: Value) throws -> Instruction.Binding {
        var cursor = try FieldCursor(value, of: "binding")
        let read: Instruction.Binding

        switch ObjectLayout.BindingTag(rawValue: try cursor.field().integer()) {
        case .bind: read = .bind(try cursor.field().count())
        case .declare: read = .declare(try cursor.field().count())
        case .assign: read = .assign(try address(cursor.next()))
        case nil: throw ObjectRefused("'binding' binds in a way this reads none of")
        }

        try cursor.end()

        return read
    }

    private func address(_ value: Value) throws -> Address {
        var cursor = try FieldCursor(value, of: "address")
        let read = Address(
            slot: try cursor.field().count(),
            steps: try cursor.field().list(walk)
        )

        try cursor.end()

        return read
    }

    private func walk(_ value: Value) throws -> Step {
        var cursor = try FieldCursor(value, of: "walk")
        let read: Step

        switch ObjectLayout.StepTag(rawValue: try cursor.field().integer()) {
        case .field:
            read = .field(try cursor.field().count(), try name(cursor.next()), optional: try cursor.field().flag())

        case .name: read = .name(try name(cursor.next()), optional: try cursor.field().flag())
        case .index: read = .index(try self.value(cursor.next()), optional: try cursor.field().flag())
        case .at: read = .at(try address(cursor.next()), optional: try cursor.field().flag())
        case nil: throw ObjectRefused("'walk' steps in a way this reads none of")
        }

        try cursor.end()

        return read
    }

    private func operation(_ value: Value) throws -> Operation {
        var cursor = try FieldCursor(value, of: "operation")
        let read: Operation

        switch ObjectLayout.OperationTag(rawValue: try cursor.field().integer()) {
        case .literal: read = .literal(try self.value(cursor.next()))
        case .local: read = .local(try address(cursor.next()))
        case .array: read = .array(try Field(cursor.next(), of: "array").list(operation))
        case .record: read = .record(try recordOperation(cursor.next()))
        case .dictionary:
            read = .dictionary(try Field(cursor.next(), of: "dictionary").list { written in
                var entry = try FieldCursor(written, of: "entry")
                let read = (key: try operation(entry.next()), value: try operation(entry.next()))

                try entry.end()

                return read
            })
        case .closure:
            read = .closure(
                try cursor.field().count(),
                captures: try Field(cursor.next(), of: "captures").list { written in
                    var held = try FieldCursor(written, of: "capture")
                    let taken = (try held.field().count(), try held.field().count())

                    try held.end()

                    return taken
                }
            )

        case .apply:
            read = .apply(
                try operation(cursor.next()),
                arguments: try Field(cursor.next(), of: "arguments").list(argument)
            )

        case .cast:
            read = .cast(
                try operation(cursor.next()),
                as: try lowered(cursor.next()),
                optional: try cursor.field().flag()
            )

        case .block: read = .block(try body(cursor.next()))
        case .conditional:
            read = .conditional(
                try operation(cursor.next()),
                then: try Field(cursor.next(), of: "then").list(instruction),
                else: try cursor.field().maybe { written in
                    try Field(written, of: "otherwise").list(instruction)
                }
            )

        case .loop:
            read = .loop(
                while: try operation(cursor.next()),
                body: try body(cursor.next()),
                round: try cursor.field().maybe(counted),
                keeps: try cursor.field().maybe { written in
                    var held = try FieldCursor(written, of: "keeps")
                    let low = try held.field().count()
                    let high = try held.field().count()

                    try held.end()

                    guard low <= high else {
                        throw ObjectRefused("'keeps' ends before it begins")
                    }

                    return low ..< high
                }
            )

        case .attempt:
            read = .attempt(
                try body(cursor.next()),
                rescue: try body(cursor.next()),
                failure: try cursor.field().maybe(counted)
            )

        case .call: read = .call(try callOperation(cursor.next()))
        case .dispatch: read = .dispatch(try dispatchOperation(cursor.next()))
        case .leave:
            read = .leave(
                try reach(cursor.next()),
                target: try cursor.field().maybe(name),
                try cursor.field().maybe(operation)
            )

        case nil:
            throw ObjectRefused("'operation' does something this reads none of")
        }

        try cursor.end()

        return read
    }

    private func recordOperation(_ value: Value) throws -> RecordOperation {
        var cursor = try FieldCursor(value, of: "record")
        let held = try layout(cursor.next())
        let read = try RecordOperation(
            layout: held,
            judging: try cursor.field().list(operation)
        )

        try cursor.end()

        return read
    }

    private func callOperation(_ value: Value) throws -> CallOperation {
        var cursor = try FieldCursor(value, of: "call")
        let read = try CallOperation(
            procedure: try cursor.field().count(),
            arguments: try Field(cursor.next(), of: "arguments").list { written in
                try Field(written, of: "argument").maybe(operation)
            },
            handing: try Field(cursor.next(), of: "handed").list { written in
                var held = try FieldCursor(written, of: "handed")
                let taken = CallOperation.Handed(
                    position: try held.field().count(),
                    address: try address(held.next())
                )

                try held.end()

                return taken
            }
        )

        try cursor.end()

        return read
    }

    private func dispatchOperation(_ value: Value) throws -> DispatchOperation {
        var cursor = try FieldCursor(value, of: "dispatch")
        let read = DispatchOperation(
            contract: try name(cursor.next()),
            procedure: try name(cursor.next()),
            first: try operation(cursor.next()),
            arguments: try Field(cursor.next(), of: "arguments").list(argument)
        )

        try cursor.end()

        return read
    }

    private func argument(_ value: Value) throws -> Argument {
        var cursor = try FieldCursor(value, of: "argument")
        let read: Argument

        switch ObjectLayout.ArgumentTag(rawValue: try cursor.field().integer()) {
        case .value: read = .value(try operation(cursor.next()))
        case .reference: read = .reference(try address(cursor.next()))
        case nil: throw ObjectRefused("'argument' is handed in a way this reads none of")
        }

        try cursor.end()

        return read
    }
}
