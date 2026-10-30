//
//  ObjectWriter.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// An object said as a value, so that the writing a document already travels
// in carries what the document compiled to as well.
//
// The dictionary is keyed by `ObjectLayout.Key`; inside a part the fields stand
// in order and a kind as its `ObjectLayout` tag before them, so any reading of
// the same format reads it back.
//
// Every list a name keys is written in name order, so one object is one
// value and one value is one writing of bytes. What nests, a type, a lowered
// type, a value, an operation and an address, is written as an entry of its
// table and held by its number, the tables filled in the order the parts are
// written. The layout is the language's, under *objects* in the
// specification.
struct ObjectWriter {
    // MARK: - Property
    private let compiled: Compiled
    private let tables = ObjectTables { key in TableWriter(of: key) }

    // MARK: - Initializer
    init(_ compiled: Compiled) {
        self.compiled = compiled
    }

    // MARK: - Public
    // What a field that may hold nothing is laid down as: a list of none or
    // one, so a value that is itself null is told from no value at all. The
    // reading of it is `Field.maybe`, and the two are one rule said from
    // each side.
    static func maybe<T, Failure: Error>(_ value: T?, _ write: (T) throws(Failure) -> Value) throws(Failure) -> Value {
        guard let value else { return .array([]) }

        return .array([try write(value)])
    }

    // The declaration that wrote a closure, its kind before its name. The
    // reading of it is `Field.declaration`.
    static func declaration(_ declaration: Closure.Declaration) -> Value {
        typealias Tag = ObjectLayout.DeclarationTag

        switch declaration {
        case let .procedure(declared): return .array([.int(Tag.procedure.rawValue), .string(declared.spelling)])
        case let .binding(declared): return .array([.int(Tag.binding.rawValue), .string(declared.spelling)])
        }
    }

    // Every part by the key it stands under, the tables last, once every
    // other part has numbered what it holds. What this cannot write is a
    // closure holding a box of the run that made it or written by a document
    // nobody wrote down, a dependency no fingerprint was worked out for, a
    // lowered type holding a struct's fields, and a table nesting past the
    // bound. Each is the one error thrown on the way down, and an object of
    // what holds it is not written.
    func value() throws(ObjectUnwritable) -> Value {
        let parts = try ObjectLayout.Key.allCases.map { (key) throws(ObjectUnwritable) -> (Name, Value) in
            (key.name, try part(key))
        }

        return .dictionary(Value.Dictionary(Dictionary(uniqueKeysWithValues: parts)))
    }

    // MARK: - Private
    // A value written down: the data as it is, and a closure by what it is
    // spelled by, since the row a link gave it is the link's. A cell held
    // is a box of the run that made the closure, and no object holds one.
    private func value(_ value: Value) throws(ObjectUnwritable) -> Value {
        try tables.values.open()

        return tables.values.append(try valueEntry(value))
    }

    // Written without a closure between a value and the values it holds, so
    // a value nested to the bound spends little stack a level, a debug
    // build's included.
    private func valueEntry(_ value: Value) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.ValueTag

        switch value {
        // A type a run read is numbered in that run's table, so an object
        // holds one only spelled.
        case let .existential(existential):
            guard case let .spelled(type) = existential.resolution else {
                throw ObjectUnwritable("a value holds a type of the run that read it")
            }

            return tagged(Tag.held, try self.value(existential.value), try self.type(type))

        case .null:
            return tagged(Tag.null)

        case .bool:
            return tagged(Tag.bool, value)

        case .int:
            return tagged(Tag.int, value)

        case .double:
            return tagged(Tag.double, value)

        case .string:
            return tagged(Tag.string, value)

        case .bytes:
            return tagged(Tag.bytes, value)

        case let .array(items):
            return tagged(Tag.array, try values(items))

        case let .struct(instance):
            return tagged(
                Tag.struct,
                name(instance.name),
                .array(instance.layout.fields.map(name)),
                try values(instance.values)
            )

        // The keys in the key order the dictionary holds them in, and the values
        // beside them.
        case let .dictionary(dictionary):
            return tagged(
                Tag.dictionary,
                try values(dictionary.keys),
                try values(dictionary.values)
            )

        case let .procedure(closure):
            return try closureForm(closure)
        }
    }

    // The values a list holds, in its order.
    private func values(_ values: some Sequence<Value>) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for value in values {
            written.append(try self.value(value))
        }

        return .array(written)
    }

    // A document nobody wrote down is one an object cannot spell, so a
    // closure such a document wrote is not written either.
    private func closureForm(_ closure: Closure) throws(ObjectUnwritable) -> Value {
        guard case let .written(identity) = closure.writer.document else {
            throw ObjectUnwritable("a value holds a closure a document nobody wrote down wrote")
        }

        let spelled = closure.spelled()
        var captured: [Value] = []

        for (slot, cell) in spelled.captured {
            guard case let .value(held) = cell else {
                throw ObjectUnwritable("a value holds a closure holding a box of the run that made it")
            }

            captured.append(.array([.int(slot), try value(held)]))
        }

        return tagged(
            ObjectLayout.ValueTag.closure,
            .bytes(identity.bytes),
            Self.declaration(closure.writer.declaration),
            .int(closure.nth),
            .array(captured),
            try keyed(spelled.types, type)
        )
    }

    // One part of an object, by the one case that names its key, so a key the
    // layout gains is a case this has to write.
    private func part(_ key: ObjectLayout.Key) throws(ObjectUnwritable) -> Value {
        switch key {
        case .object:
            return .int(ObjectLayout.format)

        case .document:
            return document(compiled.document)

        // A document compiled against an object nobody worked a fingerprint
        // out for cannot say what it is true against, and an object that says
        // less than it leans on is one a cache would hand back wrongly.
        case .dependencies:
            guard let dependencies = compiled.dependencies else {
                throw ObjectUnwritable("the document leans on one no fingerprint was worked out for")
            }

            return .array(dependencies.map { fingerprint in .bytes(fingerprint.bytes) })

        case .types:
            return try keyed(compiled.types, declaration)

        case .contracts:
            return try keyed(compiled.contracts) { (contract) throws(ObjectUnwritable) -> Value in
                .array([
                    .array(contract.types.sorted().map(name)),
                    keyed(contract.bounds) { contracts in .array(contracts.sorted().map(name)) },
                    try keyed(contract.procedures, signature)
                ])
            }

        case .claims:
            return try headed(compiled.claims) { contracts in .array(contracts.sorted().map(name)) }

        case .members:
            return try headed(compiled.members) { members in .array(members.sorted().map(name)) }

        case .typeMembers:
            return try headed(compiled.typeMembers) { (types) throws(ObjectUnwritable) -> Value in
                try keyed(types, type)
            }

        case .importedClaims:
            return .array(compiled.importedClaims.sorted().map { pair in
                .array([name(pair.type), name(pair.contract)])
            })

        // The rows the document declares stand under their spellings; the
        // rows its bodies lifted stand apart, and what wrote each is the
        // numbering's to say, so they carry no spelling.
        case .rows:
            return .array(try compiled.table[compiled.standing].map { (row) throws(ObjectUnwritable) -> Value in
                try judged(row, spelled: true)
            })

        // What the bodies number their calls from, and their types.
        case .numbering:
            return compiled.numbering.written(dropping: compiled.declared.count)

        case .lifted:
            return .array(try compiled.table[compiled.lifted].map { (row) throws(ObjectUnwritable) -> Value in
                try judged(row, spelled: false)
            })

        case .typeNumbering:
            return compiled.typeNumbering.written

        case .variables:
            return .array(try compiled.variables.map { (entry) throws(ObjectUnwritable) -> Value in
                .array([name(entry.name), try value(entry.value)])
            })

        case .constants:
            return .array(compiled.constants.map(name))

        case .typeTable:
            return .array(tables.types.entries)

        case .loweredTypeTable:
            return .array(tables.loweredTypes.entries)

        case .valueTable:
            return .array(tables.values.entries)

        case .operationTable:
            return .array(tables.operations.entries)

        case .addressTable:
            return .array(tables.addresses.entries)
        }
    }

    // A kind as its layout writes it: the tag, and what the kind holds after it.
    private func tagged(_ tag: some RawRepresentable<Int>, _ fields: Value...) -> Value {
        .array([self.tag(tag)] + fields)
    }

    private func tag(_ tag: some RawRepresentable<Int>) -> Value {
        .int(tag.rawValue)
    }

    // A list a name keys, in name order. The order is the whole of what makes
    // two writings of one object the same bytes, since a dictionary has none
    // to lend.
    private func keyed<T, Failure: Error>(
        _ entries: [Name: T],
        _ write: (T) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        var written: [Value] = []

        for (key, entry) in entries.sorted(by: { one, other in one.key < other.key }) {
            written.append(.array([name(key), try write(entry)]))
        }

        return .array(written)
    }

    // A list a head keys, in the order of the heads' spellings.
    private func headed<T>(
        _ entries: [Head: T],
        _ write: (T) throws(ObjectUnwritable) -> Value
    ) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for (head, entry) in entries.sorted(by: { one, other in one.key < other.key }) {
            written.append(.array([try self.head(head), try write(entry)]))
        }

        return .array(written)
    }

    // A head is written as its type's name where it is bare, and otherwise
    // `[name, arguments, bounds]`: the types it applies its type to in order,
    // and each of its type parameters beside the contracts it is bounded by.
    private func head(_ head: Head) throws(ObjectUnwritable) -> Value {
        guard !head.isBare else { return name(head.type) }

        return .array([
            name(head.type),
            .array(try head.arguments.map(type)),
            keyed(head.bounds) { contracts in .array(contracts.sorted().map(name)) }
        ])
    }

    private func name(_ name: Name) -> Value {
        .string(name.spelling)
    }

    private func document(_ document: Place.Document) -> Value {
        ObjectWriter.maybe(document.identity) { identity in .bytes(identity.bytes) }
    }

    // A declared type: a struct under the struct's tag, its fields by name,
    // then, where it takes any, its type parameters in order and their
    // bounds by name, and an alias as the type it stands for.
    private func declaration(_ declared: TypeDeclaration) throws(ObjectUnwritable) -> Value {
        switch declared {
        case let .struct(fields, typeParameters, bounds):
            let written = try keyed(fields, type)

            guard !typeParameters.isEmpty else { return tagged(ObjectLayout.TypeTag.struct, written) }

            return tagged(
                ObjectLayout.TypeTag.struct,
                written,
                .array(typeParameters.map(name)),
                keyed(bounds) { contracts in .array(contracts.sorted().map(name)) }
            )

        case let .alias(stands):
            return try type(stands)
        }
    }

    private func type(_ expression: TypeExpression) throws(ObjectUnwritable) -> Value {
        try tables.types.open()

        return tables.types.append(try typeEntry(expression))
    }

    // Written without a closure between a type and the types it holds, so a
    // type nested to the bound spends little stack a level, a debug build's
    // included.
    private func typeEntry(_ expression: TypeExpression) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.TypeTag

        switch expression {
        case .any:
            return tagged(Tag.any)

        case .never:
            return tagged(Tag.never)

        case .null:
            return tagged(Tag.null)

        case .bool:
            return tagged(Tag.bool)

        case .int:
            return tagged(Tag.int)

        case .double:
            return tagged(Tag.double)

        case .string:
            return tagged(Tag.string)

        case let .array(element):
            return tagged(Tag.array, try type(element))

        case let .dictionary(key, value):
            return tagged(Tag.dictionary, try type(key), try type(value))

        case let .procedure(written, constness, isolation):
            return try procedureForm(written, constness, isolation)

        case let .variable(held):
            return tagged(Tag.variable, try type(held))

        case let .inout(held):
            return tagged(Tag.`inout`, try type(held))

        case let .optional(held):
            return tagged(Tag.optional, try type(held))

        case let .named(spelling, arguments):
            return try namedForm(spelling, arguments)

        case let .parameter(spelling):
            return tagged(Tag.parameter, name(spelling))

        case let .composition(names):
            return tagged(Tag.composition, .array(names.sorted().map(name)))

        case .selfType:
            return tagged(Tag.selfType)

        case let .associatedType(associated):
            return tagged(Tag.associatedType, name(associated.owner), name(associated.name))
        }
    }

    // What a struct is applied to follows its name where it is applied to
    // anything.
    private func namedForm(_ spelling: Name, _ arguments: [TypeExpression]) throws(ObjectUnwritable) -> Value {
        guard !arguments.isEmpty else { return tagged(ObjectLayout.TypeTag.named, name(spelling)) }

        var written: [Value] = []

        for argument in arguments {
            written.append(try type(argument))
        }

        return tagged(ObjectLayout.TypeTag.named, name(spelling), .array(written))
    }

    // A procedure type is `[parameters, returns, failing]`: the types it is
    // applied with, in position order, what it returns, and what it may fail
    // with.
    private func procedureForm(
        _ written: ProcedureType?,
        _ constness: Constness,
        _ isolation: Isolation
    ) throws(ObjectUnwritable) -> Value {
        var signature: [Value] = []

        if let written {
            var parameters: [Value] = []

            for parameter in written.parameters {
                parameters.append(try type(parameter))
            }

            signature = [.array([.array(parameters), try type(written.returns), failing(written.failing)])]
        }

        return tagged(ObjectLayout.TypeTag.procedure, .array(signature), self.constness(constness), self.isolation(isolation))
    }

    private func signature(_ signature: Signature) throws(ObjectUnwritable) -> Value {
        .array([
            .array(try signature.parameters.map(parameter)),
            try type(signature.returns),
            failing(signature.failing),
            constness(signature.constness),
            isolation(signature.isolation),
            keyed(signature.bounds) { contracts in .array(contracts.sorted().map(name)) },
            try keyed(signature.sameTypes, type)
        ])
    }

    // A parameter taking anything writes no type, as its document does.
    private func parameter(_ parameter: Parameter) throws(ObjectUnwritable) -> Value {
        .array([
            name(parameter.name),
            try ObjectWriter.maybe(parameter.type == .any ? nil : parameter.type, type)
        ])
    }

    // Ordered from the narrowest scope out, which is why the word a
    // declaration wears when it says nothing is not the zero here.
    private func access(_ access: Access) -> Value {
        typealias Tag = ObjectLayout.AccessTag

        switch access {
        case .private:
            return tag(Tag.`private`)

        case .internal:
            return tag(Tag.`internal`)

        case .public:
            return tag(Tag.`public`)
        }
    }

    private func constness(_ constness: Constness) -> Value {
        typealias Tag = ObjectLayout.ConstnessTag

        switch constness {
        case .unstated:
            return tag(Tag.unstated)

        case .const:
            return tag(Tag.const)
        }
    }

    private func isolation(_ isolation: Isolation) -> Value {
        typealias Tag = ObjectLayout.IsolationTag

        switch isolation {
        case .unstated:
            return tag(Tag.unstated)

        case .isolated:
            return tag(Tag.isolated)
        }
    }

    private func failing(_ failing: Failing) -> Value {
        typealias Tag = ObjectLayout.FailingTag

        switch failing {
        case .anything:
            return tagged(Tag.anything)

        case let .these(types):
            return tagged(Tag.these, .array(types.sorted().map(Value.string)))
        }
    }

    // A layout is written `[name, fields]`: the declared struct's name, and
    // the field names in their order.
    private func layout(_ layout: Layout) -> Value {
        .array([name(layout.name), .array(layout.fields.map(name))])
    }

    private func lowered(_ type: LoweredType) throws(ObjectUnwritable) -> Value {
        try tables.loweredTypes.open()

        return tables.loweredTypes.append(try loweredEntry(type))
    }

    private func loweredEntry(_ type: LoweredType) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.LoweredTypeTag

        switch type {
        case .any:
            return tagged(Tag.any)

        case .never:
            return tagged(Tag.never)

        case .null:
            return tagged(Tag.null)

        case .bool:
            return tagged(Tag.bool)

        // What a literal reads as is an Int once a name holds it, and only
        // a reading as a name holds it reaches an object.
        case .int, .wholeLiteral:
            return tagged(Tag.int)

        case .double:
            return tagged(Tag.double)

        case .string:
            return tagged(Tag.string)

        case let .array(element):
            return tagged(Tag.array, try lowered(element))

        case let .dictionary(key, value):
            return tagged(Tag.dictionary, try lowered(key), try lowered(value))

        // A declared struct's fields are its declaration's, written under
        // `types`; a body stands on the struct by its name alone.
        case .struct:
            throw ObjectUnwritable(
                "a lowered type holds a struct's fields, and an object names a struct"
                    + " by its place in 'typeNumbering'"
            )

        case let .procedure(signature, constness, isolation):
            return tagged(
                Tag.procedure,
                try ObjectWriter.maybe(signature?.parameters) { (written) throws(ObjectUnwritable) -> Value in
                    .array(try written.map(lowered))
                },
                try ObjectWriter.maybe(signature?.returns, lowered),
                ObjectWriter.maybe(signature?.failing, failing),
                self.constness(constness),
                self.isolation(isolation)
            )

        case let .variable(held):
            return tagged(Tag.variable, try lowered(held))

        case let .inout(held):
            return tagged(Tag.`inout`, try lowered(held))

        case let .optional(held):
            return tagged(Tag.optional, try lowered(held))

        case let .named(row, arguments):
            guard !arguments.isEmpty else { return tagged(Tag.named, .int(row)) }

            return tagged(Tag.named, .int(row), .array(try arguments.map(lowered)))

        case let .parameter(label, bounds):
            return tagged(Tag.parameter, name(label), .array(bounds.sorted().map(name)))

        case let .composition(bounds):
            return tagged(Tag.composition, .array(bounds.sorted().map(name)))
        }
    }

    private func judged(_ row: Judged, spelled: Bool) throws(ObjectUnwritable) -> Value {
        .array((spelled ? [name(row.label)] : []) + [
            try signature(row.signature),
            access(row.access),
            try implementation(row.implementation)
        ])
    }

    private func implementation(_ implementation: Judged.Implementation) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.ImplementationTag

        switch implementation {
        case let .body(body, frame):
            return tagged(Tag.body, try self.body(body), self.frame(frame))

        case let .native(sending):
            return tagged(Tag.native, .array(sending.map(send)))
        }
    }

    private func send(_ send: Native.Send) -> Value {
        .array([.int(send.position), name(send.selector), .int(send.handing)])
    }

    private func frame(_ frame: Frame) -> Value {
        .array([
            .int(frame.size),
            .array(frame.parameters.map(Value.int)),
            .array(frame.variables.map { entry in .array([.int(entry.variable), .int(entry.slot)]) }),
            .array(frame.captures.map(Value.int)),
            .array(frame.names.map(name))
        ])
    }

    private func body(_ body: LoweredBody) throws(ObjectUnwritable) -> Value {
        try instructions(body.instructions)
    }

    private func instructions(_ instructions: [Instruction]) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for instruction in instructions {
            written.append(try self.instruction(instruction))
        }

        return .array(written)
    }

    private func instruction(_ instruction: Instruction) throws(ObjectUnwritable) -> Value {
        .array([
            try ObjectWriter.maybe(instruction.binding, binding),
            try operation(instruction.code),
            .string(instruction.label)
        ])
    }

    private func binding(_ binding: Instruction.Binding) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.BindingTag

        switch binding {
        case let .bind(slot):
            return tagged(Tag.bind, .int(slot))

        case let .declare(slot):
            return tagged(Tag.declare, .int(slot))

        case let .assign(address):
            return tagged(Tag.assign, try self.address(address))
        }
    }

    private func address(_ address: Address) throws(ObjectUnwritable) -> Value {
        try tables.addresses.open()

        return tables.addresses.append(
            .array([.int(address.slot), .array(try address.steps.map(walk)), .bool(address.promoted)])
        )
    }

    private func walk(_ step: Step) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.StepTag

        switch step {
        case let .field(position, spelling, optional):
            return tagged(Tag.field, .int(position), name(spelling), .bool(optional))

        case let .name(spelling, optional):
            return tagged(Tag.name, name(spelling), .bool(optional))

        case let .index(index, optional):
            return tagged(Tag.index, try value(index), .bool(optional))

        case let .at(address, optional, coercion):
            return tagged(
                Tag.at,
                try self.address(address),
                .bool(optional),
                try ObjectWriter.maybe(coercion) { (coercion) throws(ObjectUnwritable) -> Value in
                    try self.coercion(coercion)
                }
            )
        }
    }

    private func coercion(_ coercion: Coercion) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.CoercionTag

        switch coercion {
        case let .held(reading, place):
            return tagged(Tag.held, try lowered(reading), try lowered(place))

        case .dropped:
            return tagged(Tag.dropped)

        case let .wrapped(inner, steps):
            return tagged(
                Tag.wrapped,
                try ObjectWriter.maybe(inner) { (inner) throws(ObjectUnwritable) -> Value in
                    try self.coercion(inner)
                },
                walked(steps)
            )
        }
    }

    private func walked(_ steps: [Coercion.Step]) -> Value {
        typealias Tag = ObjectLayout.PromotionStepTag

        return .array(steps.map { step in
            switch step {
            case .element: .int(Tag.element.rawValue)
            case .key: .int(Tag.key.rawValue)
            case .value: .int(Tag.value.rawValue)
            }
        })
    }

    private func operation(_ operation: Operation) throws(ObjectUnwritable) -> Value {
        try tables.operations.open()

        return tables.operations.append(try operationEntry(operation))
    }

    // One function a kind, and the operations, arguments and instructions an
    // operation lists written by loops, so an expression nested to the bound
    // spends little stack a level, a debug build's included.
    private func operationEntry(_ operation: Operation) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.OperationTag

        switch operation {
        case let .literal(value): return tagged(Tag.literal, try self.value(value))
        case let .local(address): return tagged(Tag.local, try self.address(address))
        case let .array(elements): return tagged(Tag.array, try operations(elements))
        case let .struct(built): return tagged(Tag.struct, try structOperation(built))
        case let .dictionary(entries): return tagged(Tag.dictionary, try self.entries(entries))
        case let .closure(number, captures): return closureOperation(number, captures: captures)
        case let .apply(callee, arguments): return try applyOperation(callee, arguments: arguments)
        case let .cast(read, as: type, optional: optional): return try castOperation(read, as: type, optional: optional)
        case let .coerced(read, coercion): return tagged(Tag.coerced, try self.operation(read), try self.coercion(coercion))
        case let .conditional(condition, then: then, else: otherwise):
            return try conditionalOperation(condition, then: then, else: otherwise)
        case let .loop(while: condition, body: body, round: round):
            return try loopOperation(condition, body: body, round: round)
        case let .try(body, catch: `catch`, failure: failure):
            return try tryOperation(body, catch: `catch`, failure: failure)
        case let .unwrap(read, then: then, else: otherwise, payload: payload):
            return try unwrapOperation(read, then: then, else: otherwise, payload: payload)
        case let .call(call): return tagged(Tag.call, try callOperation(call))
        case let .dispatch(dispatch): return tagged(Tag.dispatch, try dispatchOperation(dispatch))
        case let .leave(leave): return try leaveOperation(leave)
        }
    }

    private func closureOperation(_ number: Int, captures: [(Int, Int)]) -> Value {
        tagged(
            ObjectLayout.OperationTag.closure,
            .int(number),
            .array(captures.map { capture in .array([.int(capture.0), .int(capture.1)]) })
        )
    }

    private func applyOperation(_ callee: Operation, arguments: [Argument]) throws(ObjectUnwritable) -> Value {
        tagged(ObjectLayout.OperationTag.apply, try operation(callee), try self.arguments(arguments))
    }

    private func castOperation(
        _ read: Operation,
        as type: LoweredType,
        optional: Bool
    ) throws(ObjectUnwritable) -> Value {
        tagged(ObjectLayout.OperationTag.cast, try operation(read), try lowered(type), .bool(optional))
    }

    private func conditionalOperation(
        _ condition: Operation,
        then: [Instruction],
        else otherwise: [Instruction]?
    ) throws(ObjectUnwritable) -> Value {
        tagged(
            ObjectLayout.OperationTag.conditional,
            try operation(condition),
            try instructions(then),
            try ObjectWriter.maybe(otherwise, instructions)
        )
    }

    private func loopOperation(
        _ condition: Operation,
        body: [Instruction],
        round: Int?
    ) throws(ObjectUnwritable) -> Value {
        tagged(
            ObjectLayout.OperationTag.loop,
            try operation(condition),
            try instructions(body),
            ObjectWriter.maybe(round) { round in .int(round) }
        )
    }

    private func tryOperation(
        _ body: [Instruction],
        `catch`: [Instruction],
        failure: Int?
    ) throws(ObjectUnwritable) -> Value {
        tagged(
            ObjectLayout.OperationTag.try,
            try instructions(body),
            try instructions(`catch`),
            ObjectWriter.maybe(failure) { failure in .int(failure) }
        )
    }

    private func unwrapOperation(
        _ read: Operation,
        then: [Instruction]?,
        else otherwise: [Instruction]?,
        payload: Int?
    ) throws(ObjectUnwritable) -> Value {
        tagged(
            ObjectLayout.OperationTag.unwrap,
            try operation(read),
            try ObjectWriter.maybe(then, instructions),
            try ObjectWriter.maybe(otherwise, instructions),
            ObjectWriter.maybe(payload) { payload in .int(payload) }
        )
    }

    // The reach, and then the part that reach has.
    private func leaveOperation(_ leave: LeaveOperation) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.ReachTag

        switch leave {
        case let .procedure(returned):
            return tagged(ObjectLayout.OperationTag.leave, tag(Tag.procedure), try ObjectWriter.maybe(returned, operation))

        case let .loop(target):
            return tagged(ObjectLayout.OperationTag.leave, tag(Tag.loop), ObjectWriter.maybe(target, name))

        case let .round(target):
            return tagged(ObjectLayout.OperationTag.leave, tag(Tag.round), ObjectWriter.maybe(target, name))
        }
    }

    // The operations a list holds, in its order.
    private func operations(_ operations: [Operation]) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for operation in operations {
            written.append(try self.operation(operation))
        }

        return .array(written)
    }

    // Each key before its value.
    private func entries(_ entries: [(key: Operation, value: Operation)]) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for entry in entries {
            written.append(.array([try operation(entry.key), try operation(entry.value)]))
        }

        return .array(written)
    }

    private func arguments(_ arguments: [Argument]) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for argument in arguments {
            written.append(try self.argument(argument))
        }

        return .array(written)
    }

    private func structOperation(_ built: StructOperation) throws(ObjectUnwritable) -> Value {
        .array([layout(built.layout), try operations(built.fields)])
    }

    private func callOperation(_ call: CallOperation) throws(ObjectUnwritable) -> Value {
        .array([
            .int(call.placed.procedure),
            try handedArguments(call.placed.arguments),
            .array(try call.placed.handed.map { (handed) throws(ObjectUnwritable) -> Value in
                .array([.int(handed.position), try address(handed.address)])
            }),
            .array(try call.types.map(lowered))
        ])
    }

    // What a call writes at each position, and nothing where what it hands
    // in place stands.
    private func handedArguments(_ arguments: [Operation?]) throws(ObjectUnwritable) -> Value {
        var written: [Value] = []

        for argument in arguments {
            written.append(try ObjectWriter.maybe(argument, operation))
        }

        return .array(written)
    }

    // Without the calls beside it. Which row satisfies a contract is the link's
    // to say and an object stands before one, so writing them down would be
    // writing a fact this document does not hold.
    private func dispatchOperation(_ dispatch: DispatchOperation) throws(ObjectUnwritable) -> Value {
        .array([
            name(dispatch.contract),
            name(dispatch.procedure),
            .array(try dispatch.types.map(lowered)),
            try argument(dispatch.first),
            try arguments(dispatch.arguments)
        ])
    }

    private func argument(_ argument: Argument) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.ArgumentTag

        switch argument {
        case let .value(operation):
            return tagged(Tag.value, try self.operation(operation))

        case let .reference(address):
            return tagged(Tag.reference, try self.address(address))
        }
    }
}
