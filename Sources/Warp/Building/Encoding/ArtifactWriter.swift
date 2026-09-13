//
//  ArtifactWriter.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// An artifact said as a value, so that the writing a document already travels
// in carries what the document compiled to as well.
//
// A part is written as its fields in order and a kind as its case before
// them. Nothing names its own fields: what reads this is the reading beside
// it, compiled from the same declarations, and an artifact written by another
// runtime is refused before it is read rather than understood halfway.
//
// Every list a name keys is written in name order, so one artifact is one
// value and one value is one writing of bytes.
struct ArtifactWriter {
    // MARK: - Initializer
    init() { }

    // MARK: - Internal
    // What a field that may hold nothing is laid down as: a list of none or
    // one, so a value that is itself null is told from no value at all. The
    // reading of it is `Fields.maybe`, and the two are one rule said from
    // each side.
    static func maybe<T>(_ value: T?, _ write: (T) -> Value) -> Value {
        value.map { held in .array([write(held)]) } ?? .array([])
    }

    func value(of compiled: Compiled) throws -> Value {
        let written: Value = .array([
            document(compiled.document),
            keyed(compiled.types, type),
            keyed(compiled.constraints) { types in .array(types.map(type)) },
            keyed(compiled.contracts) { procedures in keyed(procedures, signature) },
            keyed(compiled.claims) { contracts in .array(contracts.sorted().map(name)) },
            .array(compiled.leaned.keys.sorted().map { claim in
                .array([name(claim.type), name(claim.contract), place(compiled.leaned[claim]!)])
            }),
            .array(compiled.declared.map(name)),
            .array(compiled.table.map(judged)),
            .array(compiled.calls.map { called in .array(called.map(name)) }),
            keyed(compiled.answers, lowered),
            try compiled.numbering.written(declaring: compiled.declared.count),
            typeNumbering(compiled.typeNumbering),
            .array(compiled.variables.map { entry in
                .array([name(entry.name), entry.value])
            })
        ])

        // A procedure is not data, and what a value of one holds is the row a
        // link gave it. Asked of what came out rather than of each place a
        // value is embedded: a folded closure reaches an artifact through a
        // module variable and through a body's literal both, and a third way
        // would be refused here without this having to hear about it.
        guard !written.holdsProcedure else {
            throw ArtifactRefused(
                "this document settles a procedure into a value, and an"
                    + " artifact carries values as data"
            )
        }

        return written
    }

    // MARK: - Private
    // A list a name keys, in name order. The order is the whole of what makes
    // two writings of one artifact the same bytes, since a dictionary has none
    // to lend.
    private func keyed<T>(_ entries: [Name: T], _ write: (T) -> Value) -> Value {
        .array(entries.keys.sorted().map { key in
            .array([name(key), write(entries[key]!)])
        })
    }

    private func name(_ name: Name) -> Value {
        .string(name.spelling)
    }

    private func document(_ document: Place.Document) -> Value {
        ArtifactWriter.maybe(document.identity) { identity in .bytes(identity.bytes) }
    }

    private func type(_ expression: TypeExpression) -> Value {
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

        case .bytes:
            return .array([.int(7)])

        case .number:
            return .array([.int(8)])

        case let .ranged(refinement):
            return .array([.int(9), ranged(refinement)])

        case let .array(element):
            return .array([.int(10), type(element)])

        case let .dictionary(element):
            return .array([.int(11), type(element)])

        case let .record(fields):
            return .array([.int(12), keyed(fields, type)])

        case let .procedure(written, purity, isolation):
            return .array([
                .int(13),
                ArtifactWriter.maybe(written, signature),
                self.purity(purity),
                self.isolation(isolation)
            ])

        case let .variable(held):
            return .array([.int(14), type(held)])

        case let .inout(held):
            return .array([.int(15), type(held)])

        case let .linear(held):
            return .array([.int(16), type(held)])

        case let .consuming(held):
            return .array([.int(17), type(held)])

        case let .borrowing(held):
            return .array([.int(18), type(held)])

        case let .nullable(held):
            return .array([.int(19), type(held)])

        case let .named(spelling):
            return .array([.int(20), name(spelling)])

        case let .parameter(spelling, constraint):
            return .array([.int(21), name(spelling), ArtifactWriter.maybe(constraint, name)])

        case let .reading(of: read, path: path):
            return .array([.int(22), name(read), .array(path.map(segment))])
        }
    }

    private func ranged(_ refinement: TypeExpression.Refinement) -> Value {
        switch refinement {
        case let .whole(from, to):
            return .array([
                .int(0),
                ArtifactWriter.maybe(from) { floor in .int(floor) },
                ArtifactWriter.maybe(to) { ceiling in edge(ceiling) { bound in .int(bound) } }
            ])

        case let .fraction(from, to):
            return .array([
                .int(1),
                ArtifactWriter.maybe(from) { floor in .double(floor) },
                ArtifactWriter.maybe(to) { ceiling in edge(ceiling) { bound in .double(bound) } }
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

    private func signature(_ signature: Signature) -> Value {
        .array([
            ArtifactWriter.maybe(signature.receiver, name),
            keyed(signature.parameters, parameter),
            ArtifactWriter.maybe(signature.returns, type)
        ])
    }

    private func parameter(_ parameter: Parameter) -> Value {
        .array([
            ArtifactWriter.maybe(parameter.type, type),
            ArtifactWriter.maybe(parameter.candidates) { written in .array(written.map(Value.string)) },
            ArtifactWriter.maybe(parameter.default) { held in held },
            ArtifactWriter.maybe(parameter.description, Value.string)
        ])
    }

    private func purity(_ purity: Purity) -> Value {
        switch purity {
        case .unstated:
            return .int(0)

        case .pure:
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

private extension ArtifactWriter {
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
            return .array([.int(4), ArtifactWriter.maybe(spelling, Value.string), .int(at)])

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
        .array([ArtifactWriter.maybe(layout.name, name), .array(layout.fields.map(name))])
    }
}

private extension ArtifactWriter {
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

        case .bytes:
            return .array([.int(7)])

        case .number:
            return .array([.int(8)])

        case let .ranged(refinement):
            return .array([.int(9), ranged(refinement)])

        case let .array(element):
            return .array([.int(10), lowered(element)])

        case let .dictionary(element):
            return .array([.int(11), lowered(element)])

        case let .record(record):
            return .array([.int(12), loweredRecord(record)])

        case let .procedure(parameters, returns, purity, isolation):
            return .array([
                .int(13),
                ArtifactWriter.maybe(parameters) { written in
                    .array(written.map { parameter in
                        .array([
                            name(parameter.name),
                            lowered(parameter.type),
                            .bool(parameter.mustBeGiven)
                        ])
                    })
                },
                ArtifactWriter.maybe(returns, lowered),
                self.purity(purity),
                self.isolation(isolation)
            ])

        case let .variable(held):
            return .array([.int(14), lowered(held)])

        case let .inout(held):
            return .array([.int(15), lowered(held)])

        case let .nullable(held):
            return .array([.int(16), lowered(held)])

        case let .named(row):
            return .array([.int(17), .int(row)])

        case let .parameter(label, bound):
            return .array([.int(18), name(label), ArtifactWriter.maybe(bound, self.bound)])

        case let .reading(of: read, path: path):
            return .array([.int(19), name(read), .array(path.map(segment))])

        case let .member(row):
            return .array([.int(20), .int(row)])

        case let .undeclared(label, refusal):
            return .array([.int(21), .string(label), .string(refusal)])
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

    func typeNumbering(_ numbering: LoweredTypeNumbering) -> Value {
        .array([
            .array(numbering.types.map(name)),
            .array(numbering.memberships.map(name))
        ])
    }
}

private extension ArtifactWriter {
    func judged(_ row: Judged) -> Value {
        .array([
            name(row.label),
            signature(row.signature),
            purity(row.purity),
            isolation(row.isolation),
            failing(row.failing),
            .array(row.sends.map(sent)),
            implementation(row.implementation)
        ])
    }

    func implementation(_ implementation: Judged.Implementation) -> Value {
        switch implementation {
        case let .body(body, frame):
            return .array([.int(0), self.body(body), self.frame(frame)])

        case let .native(sending):
            return .array([.int(1), .array(sending.map(send))])
        }
    }

    func sent(_ sent: Sent) -> Value {
        .array([.int(sent.row), .array(sent.offers.map(Value.int))])
    }

    func send(_ send: Native.Send) -> Value {
        .array([.int(send.position), name(send.selector), .array(send.offers.map(name))])
    }

    func frame(_ frame: Frame) -> Value {
        .array([
            .int(frame.size),
            .array(frame.parameters.map(Value.int)),
            .array(frame.variables.map { entry in .array([.int(entry.variable), .int(entry.slot)]) }),
            .array(frame.names.map(name))
        ])
    }

    func body(_ body: Body) -> Value {
        .array([
            .array(body.instructions.map(instruction)),
            ArtifactWriter.maybe(body.result, operation)
        ])
    }

    func instruction(_ instruction: Instruction) -> Value {
        .array([
            ArtifactWriter.maybe(instruction.binding, binding),
            operation(instruction.code),
            .string(instruction.label)
        ])
    }

    func binding(_ binding: Instruction.Binding) -> Value {
        switch binding {
        case let .bind(slot, settling):
            return .array([.int(0), .int(slot), ArtifactWriter.maybe(settling, lowered)])

        case let .declare(slot, settling):
            return .array([.int(1), .int(slot), ArtifactWriter.maybe(settling, lowered)])

        case let .assign(address, settling):
            return .array([.int(2), self.address(address), ArtifactWriter.maybe(settling, lowered)])
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

private extension ArtifactWriter {
    func operation(_ operation: Operation) -> Value {
        switch operation {
        case let .literal(value):
            return .array([.int(0), value])

        case let .local(address):
            return .array([.int(1), self.address(address)])

        case let .array(elements):
            return .array([.int(2), .array(elements.map(self.operation))])

        case let .record(record):
            return .array([.int(3), recordOperation(record)])

        case let .closure(number, captures):
            return .array([
                .int(4),
                .int(number),
                .array(captures.map { capture in .array([.int(capture.0), .int(capture.1)]) })
            ])

        case let .apply(callee, arguments):
            return .array([
                .int(5),
                self.operation(callee),
                .array(arguments.map { argument in
                    .array([name(argument.0), self.operation(argument.1)])
                })
            ])

        case let .cast(read, as: type, optional: optional):
            return .array([.int(6), self.operation(read), lowered(type), .bool(optional)])

        case let .block(body):
            return .array([.int(7), self.body(body)])

        case let .conditional(condition, then: then, else: otherwise):
            return .array([
                .int(8),
                self.operation(condition),
                .array(then.map(instruction)),
                ArtifactWriter.maybe(otherwise) { written in .array(written.map(instruction)) }
            ])

        case let .loop(while: condition, body: body, round: round, keeps: keeps):
            return .array([
                .int(9),
                self.operation(condition),
                self.body(body),
                .int(round),
                ArtifactWriter.maybe(keeps) { kept in .array([.int(kept.lowerBound), .int(kept.upperBound)]) }
            ])

        case let .attempt(body, rescue: rescue, failure: failure):
            return .array([.int(10), self.body(body), self.body(rescue), .int(failure)])

        case let .call(call):
            return .array([.int(11), callOperation(call)])

        case let .dispatch(dispatch):
            return .array([.int(12), dispatchOperation(dispatch)])

        case let .leave(reach, target: target, read):
            return .array([
                .int(13),
                self.reach(reach),
                ArtifactWriter.maybe(target, name),
                ArtifactWriter.maybe(read, self.operation)
            ])
        }
    }

    func recordOperation(_ record: RecordOperation) -> Value {
        .array([layout(record.layout), .array(record.fields.map(operation))])
    }

    func callOperation(_ call: CallOperation) -> Value {
        .array([
            .int(call.procedure),
            ArtifactWriter.maybe(call.receiver, operation),
            .array(call.arguments.map { argument in ArtifactWriter.maybe(argument, self.operation) }),
            .array(call.handed.map { handed in
                .array([.int(handed.position), address(handed.address)])
            })
        ])
    }

    func dispatchOperation(_ dispatch: DispatchOperation) -> Value {
        .array([
            name(dispatch.contract),
            name(dispatch.procedure),
            operation(dispatch.receiver),
            keyed(dispatch.arguments, argument),
            keyed(dispatch.calls, callOperation)
        ])
    }

    func argument(_ argument: Argument) -> Value {
        switch argument {
        case let .value(operation):
            return .array([.int(0), self.operation(operation)])

        case let .reference(address):
            return .array([.int(1), self.address(address)])
        }
    }
}
