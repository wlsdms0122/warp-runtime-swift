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
// A part is written as its fields in order and a kind as its case before
// them. Nothing names its own fields: what reads this is the reading beside
// it, compiled from the same declarations, and an object written by another
// runtime is refused before it is read rather than understood halfway.
//
// Every list a name keys is written in name order, so one object is one
// value and one value is one writing of bytes. The layout is the language's,
// under *objects* in the specification.
struct ObjectWriter {
    // MARK: - Initializer
    init() { }

    // MARK: - Internal
    // What a field that may hold nothing is laid down as: a list of none or
    // one, so a value that is itself null is told from no value at all. The
    // reading of it is `Fields.maybe`, and the two are one rule said from
    // each side.
    static func maybe<T, Failure: Error>(_ value: T?, _ write: (T) throws(Failure) -> Value) throws(Failure) -> Value {
        guard let value else { return .array([]) }

        return .array([try write(value)])
    }

    func value(of compiled: Compiled) throws(ObjectUnwritable) -> Value {
        // A numbering counting from a link's own rows belongs to no document,
        // so what holds one is not an object and there is none to write.
        guard let numbering = compiled.numbering.written(dropping: compiled.declared.count) else {
            throw ObjectUnwritable("the document is numbered by a link's rows, and is no object")
        }

        // A document compiled against an object nobody worked a fingerprint
        // out for cannot say what it is true against, and an object that says
        // less than it leans on is one a cache would hand back wrongly.
        guard let dependencies = compiled.dependencies else {
            throw ObjectUnwritable("the document leans on one no fingerprint was worked out for")
        }

        // What this cannot write is a closure: one holding a box of the run
        // that made it, or one a document nobody wrote down wrote. Either is
        // the one error thrown on the way down, and an object of what holds
        // it is not written.
        return .dictionary(Value.Dictionary([
            Compiled.formatKey: .int(Compiled.format),
            "document": document(compiled.document),
            "dependencies": .array(dependencies.map { fingerprint in .bytes(fingerprint.bytes) }),
            "types": try keyed(compiled.types, type),
            "constraints": try keyed(compiled.constraints) { (types) throws(ObjectUnwritable) -> Value in .array(try types.map(type)) },
            "contracts": try keyed(compiled.contracts) { (procedures) throws(ObjectUnwritable) -> Value in try keyed(procedures, signature) },
            "claims": keyed(compiled.claims) { contracts in .array(contracts.sorted().map(name)) },
            "leaned": .array(compiled.leaned.keys.sorted().map { claim in
                .array([name(claim.type), name(claim.contract), place(compiled.leaned[claim]!)])
            }),
            // The rows the document declares stand under their spellings; the
            // rows its bodies lifted stand apart, and what wrote each is the
            // numbering's answer, so they carry no spelling.
            "rows": .array(try compiled.table.prefix(compiled.declared.count).map { (row) throws(ObjectUnwritable) -> Value in
                try judged(row, spelled: true)
            }),
            "lifted": .array(try compiled.table.dropFirst(compiled.declared.count).map { (row) throws(ObjectUnwritable) -> Value in
                try judged(row, spelled: false)
            }),
            "answers": keyed(compiled.answers, lowered),
            // What the bodies number their calls from, and their types.
            "numbering": numbering,
            "typeNumbering": compiled.typeNumbering.written,
            "variables": .array(try compiled.variables.map { (entry) throws(ObjectUnwritable) -> Value in
                .array([name(entry.name), try value(entry.value)])
            }),
            "constants": .array(compiled.constants.map(name))
        ]))
    }

    // A value written down: the data as it is, and a closure by what it is
    // spelled by, since the row a link gave it is the link's. A cell held
    // is a box of the run that made the closure, and no object holds one.
    func value(_ value: Value) throws(ObjectUnwritable) -> Value {
        switch value {
        case .null:
            return tagged(.null)

        case .bool:
            return tagged(.bool, value)

        case .int:
            return tagged(.int, value)

        case .double:
            return tagged(.double, value)

        case .string:
            return tagged(.string, value)

        case .bytes:
            return tagged(.bytes, value)

        case let .array(items):
            return tagged(.array, .array(try items.map(self.value)))

        case let .record(record):
            return tagged(
                .record,
                Self.maybe(record.layout.name, name),
                .array(record.layout.fields.map(name)),
                .array(try record.values.map(self.value))
            )

        case let .dictionary(dictionary):
            return tagged(
                .dictionary,
                .array(try dictionary.entries.map { (entry) throws(ObjectUnwritable) -> Value in
                    .array([name(entry.name), try self.value(entry.value)])
                })
            )

        // A document nobody wrote down is one an object cannot spell, so a
        // closure such a document wrote is not written either.
        case let .procedure(closure):
            guard case let .written(identity) = closure.writer.document else {
                throw ObjectUnwritable("a value holds a closure a document nobody wrote down wrote")
            }

            return tagged(
                .closure,
                .bytes(identity.bytes),
                name(closure.writer.name),
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

    private func tagged(_ tag: ValueTag, _ fields: Value...) -> Value {
        .array([.int(tag.rawValue)] + fields)
    }

    // MARK: - Private
    // A list a name keys, in name order. The order is the whole of what makes
    // two writings of one object the same bytes, since a dictionary has none
    // to lend.
    private func keyed<T, Failure: Error>(_ entries: [Name: T], _ write: (T) throws(Failure) -> Value) throws(Failure) -> Value {
        var written: [Value] = []

        for key in entries.keys.sorted() {
            written.append(.array([name(key), try write(entries[key]!)]))
        }

        return .array(written)
    }

    private func name(_ name: Name) -> Value {
        .string(name.spelling)
    }

    private func document(_ document: Place.Document) -> Value {
        ObjectWriter.maybe(document.identity) { identity in .bytes(identity.bytes) }
    }

    private func type(_ expression: TypeExpression) throws(ObjectUnwritable) -> Value {
        switch expression {
        case .any:
            return .array([.int(0)])

        case .never:
            return .array([.int(1)])

        case .null:
            return .array([.int(2)])

        case .bool:
            return .array([.int(3)])

        case .int:
            return .array([.int(4)])

        case .double:
            return .array([.int(5)])

        case .string:
            return .array([.int(6)])

        case let .ranged(refinement):
            return .array([.int(7), ranged(refinement)])

        case let .array(element):
            return .array([.int(8), try type(element)])

        case let .dictionary(element):
            return .array([.int(9), try type(element)])

        case let .record(fields):
            return .array([.int(10), try keyed(fields, type)])

        case let .procedure(written, constness, isolation):
            return .array([
                .int(11),
                try ObjectWriter.maybe(written, signature),
                self.constness(constness),
                self.isolation(isolation)
            ])

        case let .variable(held):
            return .array([.int(12), try type(held)])

        case let .inout(held):
            return .array([.int(13), try type(held)])

        case let .linear(held):
            return .array([.int(14), try type(held)])

        case let .consuming(held):
            return .array([.int(15), try type(held)])

        case let .borrowing(held):
            return .array([.int(16), try type(held)])

        case let .nullable(held):
            return .array([.int(17), try type(held)])

        case let .named(spelling):
            return .array([.int(18), name(spelling)])

        case let .parameter(spelling, constraints):
            return .array([.int(19), name(spelling), .array(constraints.sorted().map(name))])

        case let .reading(of: read, path: path):
            return .array([.int(21), name(read), .array(path.map(segment))])

        case let .composition(names):
            return .array([.int(20), .array(names.sorted().map(name))])
        }
    }

    private func ranged(_ refinement: TypeExpression.Refinement) -> Value {
        switch refinement {
        case let .whole(from, to):
            return .array([
                .int(0),
                ObjectWriter.maybe(from) { floor in .int(floor) },
                ObjectWriter.maybe(to) { ceiling in edge(ceiling) { bound in .int(bound) } }
            ])

        case let .fraction(from, to):
            return .array([
                .int(1),
                ObjectWriter.maybe(from) { floor in .double(floor) },
                ObjectWriter.maybe(to) { ceiling in edge(ceiling) { bound in .double(bound) } }
            ])
        }
    }

    private func edge<Bound>(
        _ edge: TypeExpression.Refinement.Edge<Bound>,
        _ write: (Bound) -> Value
    ) -> Value {
        switch edge {
        case let .through(bound):
            return .array([.int(0), write(bound)])

        case let .upTo(bound):
            return .array([.int(1), write(bound)])
        }
    }

    private func segment(_ segment: PathSegment) -> Value {
        switch segment {
        case let .key(spelling, optional):
            return .array([.int(0), name(spelling), .bool(optional)])

        case let .index(index, optional):
            return .array([.int(1), .int(index), .bool(optional)])

        case let .indexRef(path, optional):
            return .array([.int(2), .array(path.map(self.segment)), .bool(optional)])
        }
    }

    private func signature(_ signature: Signature) throws(ObjectUnwritable) -> Value {
        .array([
            ObjectWriter.maybe(signature.receiver, name),
            try keyed(signature.parameters, parameter),
            try ObjectWriter.maybe(signature.returns, type)
        ])
    }

    // A default is data a document wrote, and a document writes no procedure
    // as data. Said where a default is written, so every signature written
    // anywhere in an object is held to it, and the reader says the same
    // where one is read.
    private func parameter(_ parameter: Parameter) throws(ObjectUnwritable) -> Value {
        guard parameter.default?.holdsProcedure != true else {
            throw ObjectUnwritable("a parameter default holding a procedure, which no document writes")
        }

        return .array([
            try ObjectWriter.maybe(parameter.type, type),
            ObjectWriter.maybe(parameter.candidates) { written in .array(written.map(Value.string)) },
            try ObjectWriter.maybe(parameter.default, value),
            ObjectWriter.maybe(parameter.description, Value.string)
        ])
    }

    private func constness(_ constness: Constness) -> Value {
        switch constness {
        case .unstated:
            return .int(0)

        case .const:
            return .int(1)
        }
    }

    private func isolation(_ isolation: Isolation) -> Value {
        switch isolation {
        case .unstated:
            return .int(0)

        case .isolated:
            return .int(1)
        }
    }

    private func failing(_ failing: Failing) -> Value {
        switch failing {
        case .unstated:
            return .array([.int(0)])

        case let .these(types):
            return .array([.int(1), .array(types.sorted().map(Value.string))])
        }
    }
}

private extension ObjectWriter {
    func place(_ place: Place) -> Value {
        .array([document(place.document), .array(place.steps.map(step))])
    }

    func step(_ step: Place.Step) -> Value {
        switch step {
        case let .key(spelling):
            return .array([.int(0), .string(spelling)])

        case let .part(part):
            return .array([.int(1), self.part(part)])

        case let .construct(construct):
            return .array([.int(2), self.construct(construct)])

        case let .index(index):
            return .array([.int(3), .int(index)])

        case let .statement(spelling, at):
            return .array([.int(4), ObjectWriter.maybe(spelling, Value.string), .int(at)])

        case let .landmark(spelling):
            return .array([.int(5), .string(spelling)])
        }
    }

    func part(_ part: Place.Part) -> Value {
        switch part {
        case .procedures: return .array([.int(0)])
        case .constants: return .array([.int(1)])
        case .variables: return .array([.int(2)])
        case .types: return .array([.int(3)])
        case .constraints: return .array([.int(4)])
        case .contracts: return .array([.int(5)])
        case .satisfies: return .array([.int(6)])
        case .imports: return .array([.int(7)])
        case .parameters: return .array([.int(8)])
        case .returns: return .array([.int(9)])
        case .body: return .array([.int(10)])
        case .result: return .array([.int(11)])
        case .receiver: return .array([.int(12)])
        case .callee: return .array([.int(13)])
        case .arguments: return .array([.int(14)])
        case .closure: return .array([.int(15)])
        case let .condition(of: holder): return .array([.int(16), self.holder(holder)])
        case .then: return .array([.int(17)])
        case .otherwise: return .array([.int(18)])
        case .rescue: return .array([.int(19)])
        }
    }

    func holder(_ holder: Place.ConditionHolder) -> Value {
        switch holder {
        case .conditional: return .array([.int(0)])
        case .loop: return .array([.int(1)])
        }
    }

    func construct(_ construct: Construct) -> Value {
        switch construct {
        case .literal: return .array([.int(0)])
        case .reference: return .array([.int(1)])
        case .array: return .array([.int(2)])
        case .record: return .array([.int(3)])
        case .closure: return .array([.int(4)])
        case .cast: return .array([.int(5)])
        case .apply: return .array([.int(6)])
        case .block: return .array([.int(7)])
        case .conditional: return .array([.int(8)])
        case .loop: return .array([.int(9)])
        case .attempt: return .array([.int(10)])
        case .call: return .array([.int(11)])
        case let .leave(reach): return .array([.int(12), self.reach(reach)])
        }
    }

    func reach(_ reach: Leave.Reach) -> Value {
        switch reach {
        case .procedure: return .int(0)
        case .construct: return .int(1)
        case .round: return .int(2)
        }
    }

    func layout(_ layout: Layout) -> Value {
        .array([ObjectWriter.maybe(layout.name, name), .array(layout.fields.map(name))])
    }
}

private extension ObjectWriter {
    func lowered(_ type: LoweredType) -> Value {
        switch type {
        case .any:
            return .array([.int(0)])

        case .never:
            return .array([.int(1)])

        case .null:
            return .array([.int(2)])

        case .bool:
            return .array([.int(3)])

        case .int:
            return .array([.int(4)])

        case .double:
            return .array([.int(5)])

        case .string:
            return .array([.int(6)])

        case let .ranged(refinement):
            return .array([.int(7), ranged(refinement)])

        case let .array(element):
            return .array([.int(8), lowered(element)])

        case let .dictionary(element):
            return .array([.int(9), lowered(element)])

        case let .record(record):
            return .array([.int(10), loweredRecord(record)])

        case let .procedure(parameters, returns, constness, isolation):
            return .array([
                .int(11),
                ObjectWriter.maybe(parameters) { written in
                    .array(written.map { parameter in
                        .array([
                            name(parameter.name),
                            lowered(parameter.type),
                            .bool(parameter.defaulted)
                        ])
                    })
                },
                ObjectWriter.maybe(returns, lowered),
                self.constness(constness),
                self.isolation(isolation)
            ])

        case let .variable(held):
            return .array([.int(12), lowered(held)])

        case let .inout(held):
            return .array([.int(13), lowered(held)])

        case let .nullable(held):
            return .array([.int(14), lowered(held)])

        case let .named(row):
            return .array([.int(15), .int(row)])

        case let .parameter(label, bounds):
            return .array([.int(16), name(label), .array(bounds.sorted().map(bound))])

        case let .composition(bounds):
            return .array([.int(17), .array(bounds.sorted().map(bound))])

        case let .reading(of: read, path: path):
            return .array([.int(18), name(read), .array(path.map(segment))])

        case let .undeclared(label, because):
            return .array([.int(19), .string(label), undeclared(because)])
        }
    }

    func undeclared(_ because: LoweredType.Undeclared) -> Value {
        switch because {
        case let .noTypeNamed(name): return .array([.int(0), self.name(name)])
        case let .noBoundNamed(name): return .array([.int(1), self.name(name)])
        case .namesItself: return .array([.int(2)])
        }
    }

    func bound(_ bound: LoweredType.Bound) -> Value {
        switch bound {
        case let .membership(row):
            return .array([.int(0), .int(row)])

        case let .contract(spelling):
            return .array([.int(1), name(spelling)])
        }
    }

    func loweredRecord(_ record: LoweredRecord) -> Value {
        .array([layout(record.layout), .array(record.fields.map(lowered))])
    }

}

private extension ObjectWriter {
    func judged(_ row: Judged, spelled: Bool) throws(ObjectUnwritable) -> Value {
        .array((spelled ? [name(row.label)] : []) + [
            try signature(row.signature),
            constness(row.constness),
            isolation(row.isolation),
            failing(row.failing),
            .array(row.sends.map(sent)),
            try implementation(row.implementation)
        ])
    }

    func implementation(_ implementation: Judged.Implementation) throws(ObjectUnwritable) -> Value {
        switch implementation {
        case let .body(body, frame):
            return .array([.int(0), try self.body(body), self.frame(frame)])

        case let .native(sending):
            return .array([.int(1), .array(sending.map(send))])
        }
    }

    func sent(_ sent: Sent) -> Value {
        .array([.int(sent.row), .array(sent.handing.map(Value.int))])
    }

    func send(_ send: Native.Send) -> Value {
        .array([.int(send.position), name(send.selector), .array(send.handing.map(name))])
    }

    func frame(_ frame: Frame) -> Value {
        .array([
            .int(frame.size),
            .array(frame.parameters.map(Value.int)),
            .array(frame.variables.map { entry in .array([.int(entry.variable), .int(entry.slot)]) }),
            .array(frame.captures.map(Value.int)),
            .array(frame.names.map(name))
        ])
    }

    func body(_ body: Body) throws(ObjectUnwritable) -> Value {
        .array([
            .array(try body.instructions.map(instruction)),
            try ObjectWriter.maybe(body.result, operation)
        ])
    }

    func instruction(_ instruction: Instruction) throws(ObjectUnwritable) -> Value {
        .array([
            ObjectWriter.maybe(instruction.binding, binding),
            try operation(instruction.code),
            .string(instruction.label)
        ])
    }

    func binding(_ binding: Instruction.Binding) -> Value {
        switch binding {
        case let .bind(slot, settling):
            return .array([.int(0), .int(slot), ObjectWriter.maybe(settling, lowered)])

        case let .declare(slot, settling):
            return .array([.int(1), .int(slot), ObjectWriter.maybe(settling, lowered)])

        case let .assign(address, settling):
            return .array([.int(2), self.address(address), ObjectWriter.maybe(settling, lowered)])
        }
    }

    func address(_ address: Address) -> Value {
        .array([.int(address.slot), .array(address.steps.map(walk))])
    }

    func walk(_ step: Step) -> Value {
        switch step {
        case let .field(position, spelling, optional):
            return .array([.int(0), .int(position), name(spelling), .bool(optional)])

        case let .key(spelling, optional):
            return .array([.int(1), name(spelling), .bool(optional)])

        case let .index(index, optional):
            return .array([.int(2), .int(index), .bool(optional)])

        case let .at(address, optional):
            return .array([.int(3), self.address(address), .bool(optional)])
        }
    }
}

private extension ObjectWriter {
    func operation(_ operation: Operation) throws(ObjectUnwritable) -> Value {
        switch operation {
        case let .literal(value):
            return .array([.int(0), try self.value(value)])

        case let .local(address):
            return .array([.int(1), self.address(address)])

        case let .array(elements):
            return .array([.int(2), .array(try elements.map(self.operation))])

        case let .record(record):
            return .array([.int(3), try recordOperation(record)])

        case let .closure(number, captures):
            return .array([
                .int(4),
                .int(number),
                .array(captures.map { capture in .array([.int(capture.0), .int(capture.1)]) })
            ])

        case let .apply(callee, arguments):
            return .array([
                .int(5),
                try self.operation(callee),
                .array(try arguments.map { (argument) throws(ObjectUnwritable) -> Value in
                    .array([name(argument.0), try self.operation(argument.1)])
                })
            ])

        case let .cast(read, as: type, optional: optional):
            return .array([.int(6), try self.operation(read), lowered(type), .bool(optional)])

        case let .block(body):
            return .array([.int(7), try self.body(body)])

        case let .conditional(condition, then: then, else: otherwise):
            return .array([
                .int(8),
                try self.operation(condition),
                .array(try then.map(instruction)),
                try ObjectWriter.maybe(otherwise) { (written) throws(ObjectUnwritable) -> Value in .array(try written.map(instruction)) }
            ])

        case let .loop(while: condition, body: body, round: round, keeps: keeps):
            return .array([
                .int(9),
                try self.operation(condition),
                try self.body(body),
                .int(round),
                ObjectWriter.maybe(keeps) { kept in .array([.int(kept.lowerBound), .int(kept.upperBound)]) }
            ])

        case let .attempt(body, rescue: rescue, failure: failure):
            return .array([.int(10), try self.body(body), try self.body(rescue), .int(failure)])

        case let .call(call):
            return .array([.int(11), try callOperation(call)])

        case let .dispatch(dispatch):
            return .array([.int(12), try dispatchOperation(dispatch)])

        case let .leave(reach, target: target, read):
            return .array([
                .int(13),
                self.reach(reach),
                ObjectWriter.maybe(target, name),
                try ObjectWriter.maybe(read, self.operation)
            ])
        }
    }

    func recordOperation(_ record: RecordOperation) throws(ObjectUnwritable) -> Value {
        .array([layout(record.layout), .array(try record.fields.map(operation))])
    }

    func callOperation(_ call: CallOperation) throws(ObjectUnwritable) -> Value {
        .array([
            .int(call.procedure),
            try ObjectWriter.maybe(call.receiver, operation),
            .array(try call.arguments.map { (argument) throws(ObjectUnwritable) -> Value in try ObjectWriter.maybe(argument, self.operation) }),
            .array(call.handed.map { handed in
                .array([.int(handed.position), address(handed.address)])
            })
        ])
    }

    // Without the calls beside it. Which row answers a contract is the link's
    // answer and an object stands before one, so writing them down would be
    // writing a fact this document does not hold.
    func dispatchOperation(_ dispatch: DispatchOperation) throws(ObjectUnwritable) -> Value {
        .array([
            name(dispatch.contract),
            name(dispatch.procedure),
            try operation(dispatch.receiver),
            try keyed(dispatch.arguments, argument)
        ])
    }

    func argument(_ argument: Argument) throws(ObjectUnwritable) -> Value {
        switch argument {
        case let .value(operation):
            return .array([.int(0), try self.operation(operation)])

        case let .reference(address):
            return .array([.int(1), self.address(address)])
        }
    }
}
