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
// The record is keyed by `ObjectLayout.Key`; inside a part the fields stand
// in order and a kind as its `ObjectLayout` tag before them, so any reading of
// the same format reads it back.
//
// Every list a name keys is written in name order, so one object is one
// value and one value is one writing of bytes. The layout is the language's,
// under *objects* in the specification.
struct ObjectWriter {
    // MARK: - Property
    // MARK: - Initializer
    init() {
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
    func declaration(_ declaration: Closure.Declaration) -> Value {
        typealias Tag = ObjectLayout.DeclarationTag

        switch declaration {
        case let .procedure(declared): return tagged(Tag.procedure, name(declared))
        case let .binding(declared): return tagged(Tag.binding, name(declared))
        }
    }

    // Every part by the key it stands under. What this cannot write is a
    // closure: one holding a box of the run that made it, or one a document
    // nobody wrote down wrote. Either is the one error thrown on the way
    // down, and an object of what holds it is not written.
    func value(of compiled: Compiled) throws(ObjectUnwritable) -> Value {
        let parts = try ObjectLayout.Key.allCases.map { (key) throws(ObjectUnwritable) -> (Name, Value) in
            (key.name, try part(key, of: compiled))
        }

        return .dictionary(Value.Dictionary(Dictionary(uniqueKeysWithValues: parts)))
    }

    // A value written down: the data as it is, and a closure by what it is
    // spelled by, since the row a link gave it is the link's. A cell held
    // is a box of the run that made the closure, and no object holds one.
    func value(_ value: Value) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.ValueTag

        switch value {
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
            return tagged(Tag.array, .array(try items.map(self.value)))

        case let .record(record):
            return tagged(
                Tag.record,
                name(record.name),
                .array(record.layout.fields.map(name)),
                .array(try record.values.map(self.value))
            )

        // The keys in the key order the map holds them in, and the values
        // beside them.
        case let .dictionary(dictionary):
            return tagged(
                Tag.dictionary,
                .array(try dictionary.keys.map(self.value)),
                .array(try dictionary.values.map(self.value))
            )

        // A document nobody wrote down is one an object cannot spell, so a
        // closure such a document wrote is not written either.
        case let .procedure(closure):
            guard case let .written(identity) = closure.writer.document else {
                throw ObjectUnwritable("a value holds a closure a document nobody wrote down wrote")
            }

            return tagged(
                Tag.closure,
                .bytes(identity.bytes),
                declaration(closure.writer.declaration),
                .int(closure.nth),
                .array(try closure.captured.map { (slot, cell) throws(ObjectUnwritable) -> Value in
                    guard case let .value(held) = cell else {
                        throw ObjectUnwritable("a value holds a closure holding a box of the run that made it")
                    }

                    return .array([.int(slot), try self.value(held)])
                })
            )
        }
    }

    // MARK: - Private
    // One part of an object, by the one case that names its key, so a key the
    // layout gains is a case this has to write.
    private func part(_ key: ObjectLayout.Key, of compiled: Compiled) throws(ObjectUnwritable) -> Value {
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
            return try keyed(compiled.contracts) { (procedures) throws(ObjectUnwritable) -> Value in
                try keyed(procedures) { (asked) throws(ObjectUnwritable) -> Value in
                    .array([
                        try signature(asked.signature),
                        constness(asked.constness),
                        isolation(asked.isolation),
                        failing(.these(asked.failing))
                    ])
                }
            }

        case .claims:
            return keyed(compiled.claims) { contracts in .array(contracts.sorted().map(name)) }

        case .leaned:
            return .array(compiled.leaned.sorted { one, other in one.key < other.key }.map { claim, place in
                .array([name(claim.type), name(claim.contract), self.place(place)])
            })

        // The rows the document declares stand under their spellings; the
        // rows its bodies lifted stand apart, and what wrote each is the
        // numbering's answer, so they carry no spelling.
        case .rows:
            return .array(try compiled.table[compiled.standing].map { (row) throws(ObjectUnwritable) -> Value in
                try judged(row, spelled: true)
            })

        case .lifted:
            return .array(try compiled.table[compiled.lifted].map { (row) throws(ObjectUnwritable) -> Value in
                try judged(row, spelled: false)
            })

        case .answers:
            return try keyed(compiled.answers, lowered)

        // What the bodies number their calls from, and their types.
        case .numbering:
            return compiled.numbering.written(dropping: compiled.declared.count)

        case .typeNumbering:
            return compiled.typeNumbering.written

        case .variables:
            return .array(try compiled.variables.map { (entry) throws(ObjectUnwritable) -> Value in
                .array([name(entry.name), try value(entry.value)])
            })

        case .constants:
            return .array(compiled.constants.map(name))
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

    private func name(_ name: Name) -> Value {
        .string(name.spelling)
    }

    private func document(_ document: Place.Document) -> Value {
        ObjectWriter.maybe(document.identity) { identity in .bytes(identity.bytes) }
    }

    // A declared type: a record under the record's tag, its fields by name,
    // and an alias as the type it stands for.
    private func declaration(_ declared: TypeDeclaration) throws(ObjectUnwritable) -> Value {
        switch declared {
        case let .record(fields):
            return tagged(ObjectLayout.TypeTag.record, try keyed(fields, type))

        case let .alias(stands):
            return try type(stands)
        }
    }

    private func type(_ expression: TypeExpression) throws(ObjectUnwritable) -> Value {
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
            return tagged(
                Tag.procedure,
                try ObjectWriter.maybe(written, procedureType),
                self.constness(constness),
                self.isolation(isolation)
            )

        case let .variable(held):
            return tagged(Tag.variable, try type(held))

        case let .inout(held):
            return tagged(Tag.`inout`, try type(held))

        case let .nullable(held):
            return tagged(Tag.nullable, try type(held))

        case let .named(spelling):
            return tagged(Tag.named, name(spelling))

        case let .parameter(spelling):
            return tagged(Tag.parameter, name(spelling))

        case let .projection(of: read, path: path):
            return tagged(Tag.projection, name(read), try self.path(path))

        case let .composition(names):
            return tagged(Tag.composition, .array(names.sorted().map(name)))

        case .selfType:
            return tagged(Tag.selfType)
        }
    }

    private func path(_ path: Path) throws(ObjectUnwritable) -> Value {
        .array(try path.segments.map(segment))
    }

    private func segment(_ segment: PathSegment) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.SegmentTag

        switch segment {
        case let .name(spelling, optional):
            return tagged(Tag.name, name(spelling), .bool(optional))

        case let .index(index, optional):
            return tagged(Tag.index, try value(index), .bool(optional))

        case let .indexRef(path, optional):
            return tagged(Tag.indexRef, try self.path(path), .bool(optional))
        }
    }

    // A procedure type is `[parameters, returns]`: the types it is applied
    // with, in position order, and what it answers or nothing.
    private func procedureType(_ type: ProcedureType) throws(ObjectUnwritable) -> Value {
        .array([
            .array(try type.parameters.map(self.type)),
            try ObjectWriter.maybe(type.returns, self.type)
        ])
    }

    private func signature(_ signature: Signature) throws(ObjectUnwritable) -> Value {
        .array([
            .array(try signature.parameters.map(parameter)),
            try ObjectWriter.maybe(signature.returns, type),
            keyed(signature.bounds) { contracts in .array(contracts.sorted().map(name)) }
        ])
    }

    // A parameter taking anything writes no type, as its document does.
    private func parameter(_ parameter: Parameter) throws(ObjectUnwritable) -> Value {
        .array([
            name(parameter.name),
            try ObjectWriter.maybe(parameter.type == .any ? nil : parameter.type, type),
            ObjectWriter.maybe(parameter.description, Value.string)
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
        case .unstated:
            return tagged(Tag.unstated)

        case let .these(types):
            return tagged(Tag.these, .array(types.sorted().map(Value.string)))
        }
    }

    private func place(_ place: Place) -> Value {
        .array([document(place.document), .array(place.steps.map(step))])
    }

    private func step(_ step: Place.Step) -> Value {
        typealias Tag = ObjectLayout.PlaceStepTag

        switch step {
        case let .key(spelling):
            return tagged(Tag.key, .string(spelling))

        case let .part(part):
            return tagged(Tag.part, self.part(part))

        case let .construct(construct):
            return tagged(Tag.construct, self.construct(construct))

        case let .index(index):
            return tagged(Tag.index, .int(index))

        case let .statement(spelling, at):
            return tagged(Tag.statement, ObjectWriter.maybe(spelling, Value.string), .int(at))

        case let .landmark(spelling):
            return tagged(Tag.landmark, .string(spelling))
        }
    }

    private func part(_ part: Place.Part) -> Value {
        typealias Tag = ObjectLayout.PartTag

        switch part {
        case .procedures: return tagged(Tag.procedures)
        case .constants: return tagged(Tag.constants)
        case .variables: return tagged(Tag.variables)
        case .types: return tagged(Tag.types)
        case .contracts: return tagged(Tag.contracts)
        case .satisfies: return tagged(Tag.satisfies)
        case .imports: return tagged(Tag.imports)
        case .parameters: return tagged(Tag.parameters)
        case .returns: return tagged(Tag.returns)
        case .body: return tagged(Tag.body)
        case .result: return tagged(Tag.result)
        case let .subject(optional): return tagged(Tag.subject, .bool(optional))
        case .callee: return tagged(Tag.callee)
        case .arguments: return tagged(Tag.arguments)
        case .closure: return tagged(Tag.closure)
        case let .condition(of: holder): return tagged(Tag.condition, self.holder(holder))
        case .then: return tagged(Tag.then)
        case .otherwise: return tagged(Tag.otherwise)
        case .rescue: return tagged(Tag.rescue)
        case .fields: return tagged(Tag.fields)
        case .bounds: return tagged(Tag.bounds)
        case .entries: return tagged(Tag.entries)
        }
    }

    private func holder(_ holder: Place.ConditionHolder) -> Value {
        typealias Tag = ObjectLayout.ConditionHolderTag

        switch holder {
        case .conditional: return tagged(Tag.conditional)
        case .loop: return tagged(Tag.loop)
        }
    }

    private func construct(_ construct: Construct) -> Value {
        typealias Tag = ObjectLayout.ConstructTag

        switch construct {
        case .literal: return tagged(Tag.literal)
        case .reference: return tagged(Tag.reference)
        case .array: return tagged(Tag.array)
        case .record: return tagged(Tag.record)
        case .dictionary: return tagged(Tag.dictionary)
        case .closure: return tagged(Tag.closure)
        case .cast: return tagged(Tag.cast)
        case .block: return tagged(Tag.block)
        case .conditional: return tagged(Tag.conditional)
        case .loop: return tagged(Tag.loop)
        case .attempt: return tagged(Tag.attempt)
        case .call: return tagged(Tag.call)
        case let .leave(reach): return tagged(Tag.leave, self.reach(reach))
        }
    }

    private func reach(_ reach: Leave.Reach) -> Value {
        typealias Tag = ObjectLayout.ReachTag

        switch reach {
        case .procedure: return tag(Tag.procedure)
        case .construct: return tag(Tag.construct)
        case .round: return tag(Tag.round)
        }
    }

    // A layout is written `[name, fields]`, the name a list of one, the shape
    // a record type's layout writes where a literal's reading names none.
    private func layout(_ layout: Layout) -> Value {
        self.layout(named: layout.name, layout.fields)
    }

    private func layout(named: Name?, _ fields: [Name]) -> Value {
        .array([ObjectWriter.maybe(named, name), .array(fields.map(name))])
    }

    private func lowered(_ type: LoweredType) throws(ObjectUnwritable) -> Value {
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

        case let .record(record):
            return tagged(Tag.record, try loweredRecord(record))

        case let .procedure(signature, constness, isolation):
            return tagged(
                Tag.procedure,
                try ObjectWriter.maybe(signature?.parameters) { (written) throws(ObjectUnwritable) -> Value in
                    .array(try written.map(lowered))
                },
                try ObjectWriter.maybe(signature?.returns, lowered),
                self.constness(constness),
                self.isolation(isolation)
            )

        case let .variable(held):
            return tagged(Tag.variable, try lowered(held))

        case let .inout(held):
            return tagged(Tag.`inout`, try lowered(held))

        case let .nullable(held):
            return tagged(Tag.nullable, try lowered(held))

        case let .named(row):
            return tagged(Tag.named, .int(row))

        case let .parameter(label, bounds):
            return tagged(Tag.parameter, name(label), .array(bounds.sorted().map(name)))

        case let .composition(bounds):
            return tagged(Tag.composition, .array(bounds.sorted().map(name)))

        case let .projection(of: read, path: path):
            return tagged(Tag.projection, name(read), try self.path(path))
        }
    }

    private func loweredRecord(_ record: LoweredRecord) throws(ObjectUnwritable) -> Value {
        .array([layout(named: record.name, record.names), .array(try record.fields.map(lowered))])
    }

    private func judged(_ row: Judged, spelled: Bool) throws(ObjectUnwritable) -> Value {
        .array((spelled ? [name(row.label)] : []) + [
            try signature(row.signature),
            access(row.access),
            constness(row.constness),
            isolation(row.isolation),
            failing(row.failing),
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
        .array([
            .array(try body.instructions.map(instruction)),
            try ObjectWriter.maybe(body.result, operation)
        ])
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
        .array([.int(address.slot), .array(try address.steps.map(walk))])
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

        case let .at(address, optional):
            return tagged(Tag.at, try self.address(address), .bool(optional))
        }
    }

    private func operation(_ operation: Operation) throws(ObjectUnwritable) -> Value {
        typealias Tag = ObjectLayout.OperationTag

        switch operation {
        case let .literal(value):
            return tagged(Tag.literal, try self.value(value))

        case let .local(address):
            return tagged(Tag.local, try self.address(address))

        case let .array(elements):
            return tagged(Tag.array, .array(try elements.map(self.operation)))

        case let .record(record):
            return tagged(Tag.record, try recordOperation(record))

        case let .dictionary(entries):
            return tagged(
                Tag.dictionary,
                .array(try entries.map { (entry) throws(ObjectUnwritable) -> Value in
                    .array([try self.operation(entry.key), try self.operation(entry.value)])
                })
            )

        case let .closure(number, captures):
            return tagged(
                Tag.closure,
                .int(number),
                .array(captures.map { capture in .array([.int(capture.0), .int(capture.1)]) })
            )

        case let .apply(callee, arguments):
            return tagged(
                Tag.apply,
                try self.operation(callee),
                .array(try arguments.map(argument))
            )

        case let .cast(read, as: type, optional: optional):
            return tagged(Tag.cast, try self.operation(read), try lowered(type), .bool(optional))

        case let .block(body):
            return tagged(Tag.block, try self.body(body))

        case let .conditional(condition, then: then, else: otherwise):
            return tagged(
                Tag.conditional,
                try self.operation(condition),
                .array(try then.map(instruction)),
                try ObjectWriter.maybe(otherwise) { (written) throws(ObjectUnwritable) -> Value in
                    .array(try written.map(instruction))
                }
            )

        case let .loop(while: condition, body: body, round: round, keeps: keeps):
            return tagged(
                Tag.loop,
                try self.operation(condition),
                try self.body(body),
                ObjectWriter.maybe(round) { round in .int(round) },
                ObjectWriter.maybe(keeps) { kept in .array([.int(kept.lowerBound), .int(kept.upperBound)]) }
            )

        case let .attempt(body, rescue: rescue, failure: failure):
            return tagged(
                Tag.attempt,
                try self.body(body),
                try self.body(rescue),
                ObjectWriter.maybe(failure) { failure in .int(failure) }
            )

        case let .call(call):
            return tagged(Tag.call, try callOperation(call))

        case let .dispatch(dispatch):
            return tagged(Tag.dispatch, try dispatchOperation(dispatch))

        case let .leave(reach, target: target, read):
            return tagged(
                Tag.leave,
                self.reach(reach),
                ObjectWriter.maybe(target, name),
                try ObjectWriter.maybe(read, self.operation)
            )
        }
    }

    private func recordOperation(_ record: RecordOperation) throws(ObjectUnwritable) -> Value {
        .array([layout(record.layout), .array(try record.fields.map(operation))])
    }

    private func callOperation(_ call: CallOperation) throws(ObjectUnwritable) -> Value {
        .array([
            .int(call.procedure),
            .array(try call.arguments.map { (argument) throws(ObjectUnwritable) -> Value in
                try ObjectWriter.maybe(argument, self.operation)
            }),
            .array(try call.handed.map { (handed) throws(ObjectUnwritable) -> Value in
                .array([.int(handed.position), try address(handed.address)])
            })
        ])
    }

    // Without the calls beside it. Which row answers a contract is the link's
    // answer and an object stands before one, so writing them down would be
    // writing a fact this document does not hold.
    private func dispatchOperation(_ dispatch: DispatchOperation) throws(ObjectUnwritable) -> Value {
        .array([
            name(dispatch.contract),
            name(dispatch.procedure),
            try operation(dispatch.first),
            .array(try dispatch.arguments.map(argument))
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
