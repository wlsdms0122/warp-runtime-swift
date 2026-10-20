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
// out some other way is the format number, read before anything else. What
// nests is read out of its table where a part holds its number, in the order
// the parts are read, which is the order the writing numbered it in.
struct ObjectReader {
    // MARK: - Property
    // A struct type is written once, as a declared type's own.
    private static let structType = ObjectRefused("'type' writes a struct, which stands only as a type a document declares")
    private static let unknownTypeTag = ObjectRefused("'type' names a kind this reads none of")
    private static let unknownValueTag = ObjectRefused("'value' answers in a way this reads none of")
    private static let unknownLoweredTypeTag = ObjectRefused("'lowered type' names a kind this reads none of")
    private static let unapplied = ObjectRefused("'arguments' holds nothing, and a struct applied to no types writes no list")

    // Which document this is reading an object of. Every identity a reading
    // makes is made here, and an identity is worth having because it is
    // derived and never declared: an object writes one down, so the reading
    // holds it to the one the object was kept under.
    private let identity: Identity?

    private let parts: Keyed
    private let tables: ObjectTables<TableReader>

    // MARK: - Initializer
    init(_ value: Value, of identity: Identity?) throws {
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

        let parts = try Keyed(map)

        self.identity = identity
        self.parts = parts
        self.tables = try ObjectTables { key in try TableReader(written: try parts.part(key), of: key) }
    }

    // MARK: - Public
    // Every part read by the one case that names its key, so a key the layout
    // gains is a case this has to read.
    func compiled() throws -> Compiled {
        var dependencies: [Fingerprint] = []
        var types: [Name: TypeDeclaration] = [:]
        var contracts: [Name: Contract] = [:]
        var claims: [Head: Set<Name>] = [:]
        var members: [Head: Set<Name>] = [:]
        var typeMembers: [Head: [Name: TypeExpression]] = [:]
        var importedClaims: Set<ClaimPair> = []
        var declaredRows: [Judged] = []
        var liftedRows: [Judged] = []
        var numbering = Numbering(sends: [], declared: [])
        var typeNumbering = LoweredTypeNumbering(types: [])
        var variables: [(name: Name, value: Value)] = []
        var constants: [Name] = []

        for key in ObjectLayout.Key.allCases {
            let part = try parts.part(key)

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
                contracts = try keyed(part, of: "contracts", contract)

            // A type stands here because the document claimed a contract
            // for it, at least one.
            case .claims:
                claims = try headed(part, of: "claims") { written in
                    let contracts = try Field(written, of: "claims").ordered(name)

                    guard !contracts.isEmpty else {
                        throw ObjectRefused("'claims' claims no contract for a type")
                    }

                    return Set(contracts)
                }

            // A type is given at least one member where it stands here, and
            // each is one of the rows the document declares, which is asked
            // once every part is in.
            case .members:
                members = try headed(part, of: "members") { written in
                    let names = try Field(written, of: "members").ordered(name)

                    guard !names.isEmpty else {
                        throw ObjectRefused("'members' gives a type no member")
                    }

                    return Set(names)
                }

            // A type is given at least one type where it stands here.
            case .typeMembers:
                typeMembers = try headed(part, of: "typeMembers") { written in
                    let types = try keyed(written, of: "typeMembers", type)

                    guard !types.isEmpty else {
                        throw ObjectRefused("'typeMembers' gives a type no type")
                    }

                    return types
                }

            case .importedClaims:
                importedClaims = try self.importedClaims(part)

            // The rows the document declares stand under their spellings, one
            // per spelling in name order: what the numbering counts from and
            // what a link looks a spelling up in both stand on it.
            case .rows:
                declaredRows = try Field(part, of: "rows").list { written in
                    var cursor = try FieldCursor(written, of: "row")
                    let label = try name(cursor.next())

                    return try row(&cursor, label: label)
                }

                guard declaredRows.map(\.label).ordered else {
                    throw ObjectRefused("the declared rows stand out of name order, or one spelling stands twice")
                }

            // What the document sends and how many closures each declaration
            // wrote, which is what its bodies number their calls from.
            case .numbering:
                numbering = try Numbering(written: part, declaring: declaredRows.map(\.label))

            // A row a body lifted is spelled by the closure the numbering
            // counts at its place.
            case .lifted:
                for (index, written) in try Field(part, of: "lifted").list({ written in written }).enumerated() {
                    guard let writer = numbering.writer(of: index) else {
                        throw ObjectRefused("a lifted row stands where the numbering counts no closure")
                    }

                    var cursor = try FieldCursor(written, of: "row")

                    liftedRows.append(try row(&cursor, label: writer.by.name))
                }

            // The types its bodies stand on, which is what they number their
            // types from.
            case .typeNumbering:
                typeNumbering = try LoweredTypeNumbering(written: part)

            case .variables:
                variables = try Field(part, of: "variables").led(variable)

            case .constants:
                constants = try Field(part, of: "constants").ordered(name)

            // Opened with the reading, and read where a part holds an entry's
            // number.
            case .typeTable, .loweredTypeTable, .valueTable, .operationTable, .addressTable:
                continue
            }
        }

        for table in [tables.types, tables.loweredTypes, tables.values, tables.operations, tables.addresses] {
            try table.end()
        }

        let declared = declaredRows.map(\.label)
        let table = declaredRows + liftedRows
        let spelled = Set(declared)

        if let (head, member) = members.sorted(by: { $0.key < $1.key }).lazy.flatMap({ head, names in
            names.sorted().map { member in (head, member) }
        }).first(where: { head, member in !spelled.contains(member.spelled(under: head.type)) }) {
            throw ObjectRefused(
                "'members' gives '\(head.spelling)' the member '\(member)', and no row stands under its spelling"
            )
        }

        return try Compiled(
            document: Place.Document(identity: identity, types: types, members: members),
            types: types,
            contracts: contracts,
            claims: claims,
            members: members,
            typeMembers: typeMembers,
            importedClaims: importedClaims,
            declared: declared,
            constants: constants,
            table: table,
            numbering: numbering,
            typeNumbering: typeNumbering,
            judging: variables,
            dependencies: dependencies
        )
    }

    // MARK: - Private
    // A value as the writing laid it down: data as it is, and a closure by
    // what it is spelled by, standing without a row until a link answers one.
    private func value(_ number: Value) throws -> Value {
        let read = try valueEntry(try tables.values.open(number))

        try tables.values.close()

        return read
    }

    // A case holding a value reads it in a function of its own, so a value
    // nested to the bound spends this frame and one small one a level, a
    // debug build's included.
    private func valueEntry(_ value: Value) throws -> Value {
        var cursor = try FieldCursor(value, of: "value")
        let read: Value

        switch ObjectLayout.ValueTag(rawValue: try cursor.field().integer()) {
        case .null: read = .null
        case .bool: read = try boolForm(&cursor)
        case .int: read = .int(try cursor.field().integer())
        case .double: read = .double(try cursor.field().double())
        case .string: read = .string(try cursor.field().text())
        case .bytes: read = .bytes(try cursor.field().bytes())
        case .array: read = .array(try values(cursor.next()))
        case .struct: read = try structForm(&cursor)
        case .dictionary: read = try mapForm(&cursor)
        case .closure: read = try closureForm(&cursor)
        case nil: throw Self.unknownValueTag
        }

        try cursor.end()

        return read
    }

    // The values a list holds, in its order.
    private func values(_ written: Value) throws -> [Value] {
        var read: [Value] = []

        for number in try Field(written, of: "value").list({ number in number }) {
            read.append(try value(number))
        }

        return read
    }

    private func boolForm(_ cursor: inout FieldCursor) throws -> Value {
        guard case let .bool(held) = try cursor.next() else {
            throw ObjectRefused("'value' writes something other than a bool where one stands")
        }

        return .bool(held)
    }

    // A value the model refuses is one the writing could not have laid down,
    // and so one this reading refuses as an object.
    private func structForm(_ cursor: inout FieldCursor) throws -> Value {
        let named = try name(cursor.next())
        let names = try cursor.field().list(name)
        let values = try values(cursor.next())

        return try refusing {
            .struct(try Struct(layout: try Layout(name: named, judging: names), checking: values))
        }
    }

    // The keys in the key order, none the same as another, which is how the
    // writing lays a map down.
    private func mapForm(_ cursor: inout FieldCursor) throws -> Value {
        let keys = try values(cursor.next())
        let values = try values(cursor.next())

        guard
            keys.count == values.count,
            zip(keys, keys.dropFirst()).allSatisfy({ one, other in Value.Dictionary.order(one, other) == .orderedAscending })
        else {
            throw ObjectRefused("'map' writes its keys out of the key order, one twice, or another count than its values")
        }

        return .dictionary(Value.Dictionary(ordered: Array(zip(keys, values)).map { key, value in (key: key, value: value) }))
    }

    private func closureForm(_ cursor: inout FieldCursor) throws -> Value {
        let writer = Closure.Writer(
            document: try writing(cursor.next()),
            declaration: try cursor.field().declaration()
        )
        let nth = try cursor.field().count()
        var captured: [(slot: Int, cell: Cell)] = []

        for cell in try cursor.field().list({ cell in cell }) {
            var cell = try FieldCursor(cell, of: "captured")

            captured.append((slot: try cell.field().count(), cell: Cell.value(try value(cell.next()))))

            try cell.end()
        }

        return .procedure(Closure(writer: writer, nth: nth, linked: nil, captured: captured))
    }

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

    // A list a head keys, in the order of the heads' spellings, none twice.
    private func headed<T>(
        _ value: Value,
        of part: String,
        _ read: (Value) throws -> T
    ) throws -> [Head: T] {
        try Field(value, of: part).gathered { entry in
            var cursor = try FieldCursor(entry, of: part)
            let held = (try head(cursor.next(), of: part), try read(cursor.next()))

            try cursor.end()

            return held
        }
    }

    // A head: its type's name where it is bare, and otherwise the name, the
    // types it is applied to, at least one, and its type parameters' bounds.
    private func head(_ value: Value, of part: String) throws -> Head {
        if case .string = value {
            return Head(try name(value))
        }

        var cursor = try FieldCursor(value, of: part)
        let type = try name(cursor.next())
        let arguments = try Field(cursor.next(), of: part).list(self.type)

        guard !arguments.isEmpty else {
            throw ObjectRefused("'\(part)' applies '\(type)' to nothing, and a bare head is written as the name")
        }

        let bounds = try keyed(cursor.next(), of: part) { written in
            let contracts = try Field(written, of: part).ordered(name)

            guard !contracts.isEmpty else {
                throw ObjectRefused("'\(part)' holds a type parameter to nothing")
            }

            return Set(contracts)
        }

        try cursor.end()

        return Head(type, arguments: arguments, bounds: bounds)
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

    // Each pair a claim this document imports is about, the type and the
    // contract, in name order, none twice.
    private func importedClaims(_ value: Value) throws -> Set<ClaimPair> {
        let pairs = try Field(value, of: "importedClaims").list { entry in
            var cursor = try FieldCursor(entry, of: "importedClaims")
            let pair = ClaimPair(try name(cursor.next()), try name(cursor.next()))

            try cursor.end()

            return pair
        }

        guard zip(pairs, pairs.dropFirst()).allSatisfy({ one, other in one < other }) else {
            throw ObjectRefused("'importedClaims' writes its pairs out of order, or one of them twice")
        }

        return Set(pairs)
    }

    private func variable(_ value: Value) throws -> (name: Name, value: Value) {
        var cursor = try FieldCursor(value, of: "variable")
        let read = (name: try name(cursor.next()), value: try self.value(cursor.next()))

        try cursor.end()

        return read
    }

    // A declared type: a struct, its fields under the struct's tag and its
    // type parameters and their bounds where it takes any, or the type an
    // alias stands for.
    private func declaration(_ value: Value) throws -> TypeDeclaration {
        guard case .array = value else {
            return .alias(try type(value))
        }

        var cursor = try FieldCursor(value, of: "type")

        guard ObjectLayout.TypeTag(rawValue: try cursor.field().integer()) == .struct else {
            throw ObjectRefused("a declared type is a struct under its tag, or the number of the type an alias stands for")
        }

        let fields = try keyed(cursor.next(), of: "struct", type)

        guard !cursor.isAtEnd else { return .struct(fields) }

        let typeParameters = try Field(cursor.next(), of: "typeParameters").list(name)

        guard !typeParameters.isEmpty else {
            throw ObjectRefused("'typeParameters' lists nothing, and a struct taking none writes no list")
        }

        // Each name is one parameter, and a mention fills them by name.
        guard Set(typeParameters).count == typeParameters.count else {
            throw ObjectRefused("'typeParameters' lists a name twice, and a struct takes each type once")
        }

        let bounds = try keyed(cursor.next(), of: "bounds") { written in
            let contracts = try Field(written, of: "bounds").ordered(name)

            guard !contracts.isEmpty else {
                throw ObjectRefused("'bounds' holds a type parameter to nothing")
            }

            return Set(contracts)
        }

        try cursor.end()

        return .struct(fields, typeParameters: typeParameters, bounds: bounds)
    }

    private func type(_ number: Value) throws -> TypeExpression {
        let read = try typeEntry(try tables.types.open(number))

        try tables.types.close()

        return read
    }

    // A case holding a type reads it in a function of its own, so a type
    // nested to the bound spends this frame and one small one a level, a
    // debug build's included.
    private func typeEntry(_ value: Value) throws -> TypeExpression {
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
        case .array: read = .array(try held(&cursor))
        case .dictionary: read = try dictionaryForm(&cursor)
        case .struct: throw Self.structType
        case .procedure: read = try procedureForm(&cursor)
        case .variable: read = .variable(try held(&cursor))
        case .`inout`: read = .inout(try held(&cursor))
        case .nullable: read = .nullable(try held(&cursor))
        case .named: read = try namedForm(&cursor)
        case .parameter: read = .parameter(name: try name(cursor.next()))
        case .composition: read = try compositionForm(&cursor)
        case .selfType: read = .selfType
        case .associatedType: read = .associatedType(of: try name(cursor.next()), name: try name(cursor.next()))
        case nil: throw Self.unknownTypeTag
        }

        try cursor.end()

        return read
    }

    // The type an array, `var`, `inout` or `?` holds.
    private func held(_ cursor: inout FieldCursor) throws -> TypeExpression {
        try type(cursor.next())
    }

    private func dictionaryForm(_ cursor: inout FieldCursor) throws -> TypeExpression {
        .dictionary(key: try type(cursor.next()), value: try type(cursor.next()))
    }

    private func namedForm(_ cursor: inout FieldCursor) throws -> TypeExpression {
        let named = try name(cursor.next())

        guard !cursor.isAtEnd else { return .named(named) }

        var arguments: [TypeExpression] = []

        for argument in try Field(cursor.next(), of: "arguments").list({ argument in argument }) {
            arguments.append(try type(argument))
        }

        guard !arguments.isEmpty else {
            throw Self.unapplied
        }

        return .named(named, arguments: arguments)
    }

    // One contract is written by its name, so a composition joins two or
    // more, the way a document's does.
    private func compositionForm(_ cursor: inout FieldCursor) throws -> TypeExpression {
        let names = try Field(cursor.next(), of: "composition").ordered(name)

        guard names.count > 1 else {
            throw ObjectRefused("'composition' joins fewer than two names, and one is written as the name")
        }

        return .composition(Set(names))
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

    // A contract: the types it asks, the bounds of those it bounds, and the
    // procedures it asks. Each bound holds a type the contract asks, to one
    // contract at least.
    private func contract(_ value: Value) throws -> Contract {
        var cursor = try FieldCursor(value, of: "contract")
        let types = try Field(cursor.next(), of: "types").ordered(name)
        let bounds = try keyed(cursor.next(), of: "bounds") { written in
            let contracts = try Field(written, of: "bounds").ordered(name)

            guard !contracts.isEmpty else {
                throw ObjectRefused("'bounds' holds a type to nothing")
            }

            return Set(contracts)
        }
        let procedures = try keyed(cursor.next(), of: "contract", signature)

        try cursor.end()

        if let unasked = bounds.keys.sorted().first(where: { name in !types.contains(name) }) {
            throw ObjectRefused("'bounds' holds '\(unasked)', which the contract asks as no type")
        }

        return Contract(procedures: procedures, types: Set(types), bounds: bounds)
    }

    // Read without a closure between a type and the types it holds, since a
    // procedure type may hold one as deep as a document may nest.
    private func procedureForm(_ cursor: inout FieldCursor) throws -> TypeExpression {
        let written = try cursor.field().maybe { signature in signature }
        var procedure: ProcedureType?

        if let written {
            var signature = try FieldCursor(written, of: "procedure type")
            var parameters: [TypeExpression] = []

            for parameter in try Field(signature.next(), of: "parameters").list({ parameter in parameter }) {
                parameters.append(try type(parameter))
            }

            procedure = ProcedureType(parameters: parameters, returns: try type(signature.next()), failing: try failing(signature.next()))

            try signature.end()
        }

        return .procedure(procedure, try constness(cursor.next()), try isolation(cursor.next()))
    }

    private func signature(_ value: Value) throws -> Signature {
        var cursor = try FieldCursor(value, of: "signature")
        let read = Signature(
            parameters: try Field(cursor.next(), of: "parameters").list(parameter),
            returns: try type(cursor.next()),
            failing: try failing(cursor.next()),
            constness: try constness(cursor.next()),
            isolation: try isolation(cursor.next()),
            bounds: try keyed(cursor.next(), of: "bounds") { written in
                let contracts = try Field(written, of: "bounds").ordered(name)

                guard !contracts.isEmpty else {
                    throw ObjectRefused("'bounds' holds a type parameter to nothing")
                }

                return Set(contracts)
            },
            sameTypes: try keyed(cursor.next(), of: "sameTypes", type)
        )

        try cursor.end()

        return read
    }

    // A parameter taking anything writes no type, so a written `Any` is a
    // second writing of one signature.
    private func parameter(_ value: Value) throws -> Parameter {
        var cursor = try FieldCursor(value, of: "parameter")
        let name = try name(cursor.next())
        let type = try cursor.field().maybe(self.type)

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
        case .anything: read = .anything
        case .these:
            let failures = try cursor.field().ordered(text)

            for failure in failures where !((try? Name(failure)).map(NameGrammar.failure.holds) ?? false) {
                throw ObjectRefused("'failing' lists '\(failure)', which is no failure's name")
            }

            read = .these(Set(failures))
        case nil: throw ObjectRefused("'failing' says neither anything nor which failures")
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

    private func lowered(_ number: Value) throws -> LoweredType {
        let read = try loweredEntry(try tables.loweredTypes.open(number))

        try tables.loweredTypes.close()

        return read
    }

    // A case holding a type reads it in a function of its own, so a type
    // nested to the bound spends this frame and one small one a level, a
    // debug build's included.
    private func loweredEntry(_ value: Value) throws -> LoweredType {
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
        case .array: read = .array(try heldLowered(&cursor))
        case .dictionary: read = try loweredDictionaryForm(&cursor)
        case .procedure: read = try loweredProcedureForm(&cursor)
        case .variable: read = .variable(try heldLowered(&cursor))
        case .`inout`: read = .inout(try heldLowered(&cursor))
        case .nullable: read = .nullable(try heldLowered(&cursor))
        case .named: read = try loweredNamedForm(&cursor)
        case .parameter: read = try loweredParameterForm(&cursor)
        case .composition: read = try loweredCompositionForm(&cursor)
        case nil: throw Self.unknownLoweredTypeTag
        }

        try cursor.end()

        return read
    }

    // The type an array, `var`, `inout` or `?` holds.
    private func heldLowered(_ cursor: inout FieldCursor) throws -> LoweredType {
        try lowered(cursor.next())
    }

    // The types a list holds, in its order.
    private func lowereds(_ written: Value, of part: String) throws -> [LoweredType] {
        var read: [LoweredType] = []

        for number in try Field(written, of: part).list({ number in number }) {
            read.append(try lowered(number))
        }

        return read
    }

    private func loweredDictionaryForm(_ cursor: inout FieldCursor) throws -> LoweredType {
        .dictionary(key: try lowered(cursor.next()), value: try lowered(cursor.next()))
    }

    // A type that writes no parameters writes no signature, so it says
    // nothing of an answer or of what it may fail with either.
    private func loweredProcedureForm(_ cursor: inout FieldCursor) throws -> LoweredType {
        let parameters = try cursor.field().maybe { written in written }
        let returns = try cursor.field().maybe { written in written }
        let claimed = try cursor.field().maybe(failing)
        var signature: LoweredProcedureType?

        if let parameters, let returns, let claimed {
            signature = LoweredProcedureType(
                parameters: try lowereds(parameters, of: "parameters"),
                returns: try lowered(returns),
                failing: claimed
            )
        } else if parameters != nil || returns != nil || claimed != nil {
            throw ObjectRefused(
                "a procedure type writes what it answers and what it may fail with exactly where it"
                    + " writes what it takes"
            )
        }

        return .procedure(signature, constness: try constness(cursor.next()), isolation: try isolation(cursor.next()))
    }

    private func loweredNamedForm(_ cursor: inout FieldCursor) throws -> LoweredType {
        let row = try cursor.field().count()

        guard !cursor.isAtEnd else { return .named(row, arguments: []) }

        let arguments = try lowereds(cursor.next(), of: "arguments")

        guard !arguments.isEmpty else {
            throw Self.unapplied
        }

        return .named(row, arguments: arguments)
    }

    private func loweredParameterForm(_ cursor: inout FieldCursor) throws -> LoweredType {
        .parameter(label: try name(cursor.next()), bounds: try Field(cursor.next(), of: "bounds").ordered(name))
    }

    private func loweredCompositionForm(_ cursor: inout FieldCursor) throws -> LoweredType {
        let bounds = try Field(cursor.next(), of: "composition").ordered(name)

        guard !bounds.isEmpty else {
            throw ObjectRefused("'composition' holds a value to nothing")
        }

        return .composition(bounds)
    }

    // A row after its spelling, which a declared row writes before it and a
    // lifted row is handed by its numbering.
    private func row(_ cursor: inout FieldCursor, label: Name) throws -> Judged {
        let read = try Judged(
            label: label,
            signature: try signature(cursor.next()),
            access: try access(cursor.next()),
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
            instructions: try instructions(cursor.next(), of: "body"),
            result: try cursor.field().maybe(operation)
        )

        try cursor.end()

        return read
    }

    // The instructions a list holds, in its order.
    private func instructions(_ written: Value, of part: String) throws -> [Instruction] {
        var read: [Instruction] = []

        for held in try Field(written, of: part).list({ held in held }) {
            read.append(try instruction(held))
        }

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

    private func address(_ number: Value) throws -> Address {
        let read = try addressEntry(try tables.addresses.open(number))

        try tables.addresses.close()

        return read
    }

    private func addressEntry(_ value: Value) throws -> Address {
        var cursor = try FieldCursor(value, of: "address")
        let slot = try cursor.field().count()
        var steps: [Step] = []

        for step in try cursor.field().list({ step in step }) {
            steps.append(try walk(step))
        }

        let read = Address(slot: slot, steps: steps)

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

    private func operation(_ number: Value) throws -> Operation {
        let read = try operationEntry(try tables.operations.open(number))

        try tables.operations.close()

        return read
    }

    // Read without a closure between an operation and the operations it
    // holds, so an expression nested to the bound spends little stack a
    // level, a debug build's included.
    private func operationEntry(_ value: Value) throws -> Operation {
        var cursor = try FieldCursor(value, of: "operation")
        let read: Operation

        switch ObjectLayout.OperationTag(rawValue: try cursor.field().integer()) {
        case .literal: read = .literal(try self.value(cursor.next()))
        case .local: read = .local(try address(cursor.next()))
        case .array: read = .array(try operations(cursor.next(), of: "array"))
        case .struct: read = .struct(try structOperation(cursor.next()))
        case .dictionary: read = .dictionary(try entries(cursor.next()))
        case .closure: read = try closureOperation(&cursor)
        case .apply: read = try applyOperation(&cursor)
        case .cast: read = try castOperation(&cursor)
        case .conditional: read = try conditionalOperation(&cursor)
        case .loop: read = try loopOperation(&cursor)
        case .attempt: read = try attemptOperation(&cursor)
        case .call: read = .call(try callOperation(cursor.next()))
        case .dispatch: read = .dispatch(try dispatchOperation(cursor.next()))
        case .leave: read = try leaveOperation(&cursor)
        case nil: throw ObjectRefused("'operation' does something this reads none of")
        }

        try cursor.end()

        return read
    }

    // The operations a list holds, in its order.
    private func operations(_ written: Value, of part: String) throws -> [Operation] {
        var read: [Operation] = []

        for number in try Field(written, of: part).list({ number in number }) {
            read.append(try operation(number))
        }

        return read
    }

    // Each key before its value.
    private func entries(_ written: Value) throws -> [(key: Operation, value: Operation)] {
        var read: [(key: Operation, value: Operation)] = []

        for held in try Field(written, of: "dictionary").list({ held in held }) {
            var entry = try FieldCursor(held, of: "entry")

            read.append((key: try operation(entry.next()), value: try operation(entry.next())))
            try entry.end()
        }

        return read
    }

    private func closureOperation(_ cursor: inout FieldCursor) throws -> Operation {
        .closure(
            try cursor.field().count(),
            captures: try Field(cursor.next(), of: "captures").list { written in
                var held = try FieldCursor(written, of: "capture")
                let taken = (try held.field().count(), try held.field().count())

                try held.end()

                return taken
            }
        )
    }

    private func applyOperation(_ cursor: inout FieldCursor) throws -> Operation {
        let callee = try operation(cursor.next())
        var arguments: [Argument] = []

        for written in try Field(cursor.next(), of: "arguments").list({ written in written }) {
            arguments.append(try argument(written))
        }

        return .apply(callee, arguments: arguments)
    }

    private func castOperation(_ cursor: inout FieldCursor) throws -> Operation {
        .cast(
            try operation(cursor.next()),
            as: try lowered(cursor.next()),
            optional: try cursor.field().flag()
        )
    }

    private func conditionalOperation(_ cursor: inout FieldCursor) throws -> Operation {
        let condition = try operation(cursor.next())
        let then = try instructions(cursor.next(), of: "then")
        var otherwise: [Instruction]?

        if let written = try cursor.field().maybe({ written in written }) {
            otherwise = try instructions(written, of: "otherwise")
        }

        return .conditional(condition, then: then, else: otherwise)
    }

    private func loopOperation(_ cursor: inout FieldCursor) throws -> Operation {
        .loop(
            while: try operation(cursor.next()),
            body: try instructions(cursor.next(), of: "body"),
            round: try cursor.field().maybe(counted)
        )
    }

    private func attemptOperation(_ cursor: inout FieldCursor) throws -> Operation {
        .attempt(
            try body(cursor.next()),
            rescue: try body(cursor.next()),
            failure: try cursor.field().maybe(counted)
        )
    }

    private func leaveOperation(_ cursor: inout FieldCursor) throws -> Operation {
        let reach = try reach(cursor.next())
        let target = try cursor.field().maybe(name)

        guard let written = try cursor.field().maybe({ written in written }) else {
            return .leave(reach, target: target, nil)
        }

        return .leave(reach, target: target, try operation(written))
    }

    private func structOperation(_ value: Value) throws -> StructOperation {
        var cursor = try FieldCursor(value, of: "struct")
        let held = try layout(cursor.next())
        let read = try StructOperation(
            layout: held,
            judging: try operations(cursor.next(), of: "struct")
        )

        try cursor.end()

        return read
    }

    // What a call writes at each position, and nothing where what it hands
    // in place stands.
    private func handedArguments(_ written: Value) throws -> [Operation?] {
        var read: [Operation?] = []

        for held in try Field(written, of: "arguments").list({ held in held }) {
            guard let number = try Field(held, of: "argument").maybe({ number in number }) else {
                read.append(nil)
                continue
            }

            read.append(try operation(number))
        }

        return read
    }

    private func callOperation(_ value: Value) throws -> CallOperation {
        var cursor = try FieldCursor(value, of: "call")
        let read = try CallOperation(
            procedure: try cursor.field().count(),
            arguments: try handedArguments(cursor.next()),
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
