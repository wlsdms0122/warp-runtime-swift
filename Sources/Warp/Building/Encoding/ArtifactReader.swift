//
//  ArtifactReader.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// A value read back as the artifact it was written from.
//
// The order of the fields is the whole of the agreement with the writing
// beside it, so this holds no names and asks the value for none. What that
// agreement rests on is that the two are compiled together: an artifact a
// different runtime wrote is refused where its identity is checked, before
// any of this runs.
struct ArtifactReader {
    // MARK: - Initializer
    init() { }

    // MARK: - Internal
    func compiled(from value: Value) throws -> Compiled {
        var fields = try Fields(value, of: "artifact")

        let read = Compiled(
            document: try document(fields.next()),
            types: try keyed(fields.next(), of: "types", expression),
            constraints: try keyed(fields.next(), of: "constraints") { written in
                try list(written, of: "constraints", expression)
            },
            contracts: try keyed(fields.next(), of: "contracts") { written in
                try keyed(written, of: "contract", signature)
            },
            claims: try keyed(fields.next(), of: "claims") { written in
                Set(try list(written, of: "claims", name))
            },
            leaned: try leaned(fields.next()),
            declared: try fields.list(name),
            table: try fields.list(judged),
            calls: try fields.list { written in try list(written, of: "calls", name) },
            answers: try keyed(fields.next(), of: "answers", lowered),
            numbering: try Numbering(written: fields.next()),
            typeNumbering: try typeNumbering(fields.next()),
            variables: try fields.list(variable)
        )

        try fields.end()

        return read
    }

    // MARK: - Private
    private func list<T>(_ value: Value, of part: String, _ read: (Value) throws -> T) throws -> [T] {
        guard case let .array(written) = value else {
            throw ArtifactRefused("'\(part)' is not written as a list")
        }

        return try written.map(read)
    }

    private func keyed<T>(
        _ value: Value,
        of part: String,
        _ read: (Value) throws -> T
    ) throws -> [Name: T] {
        try list(value, of: part) { entry in
            var fields = try Fields(entry, of: part)
            let held = (Name(normal: try fields.text()), try read(fields.next()))

            try fields.end()

            return held
        }
        .reduce(into: [Name: T]()) { entries, entry in entries[entry.0] = entry.1 }
    }

    private func name(_ value: Value) throws -> Name {
        guard case let .string(spelling) = value else {
            throw ArtifactRefused("a name is not written as a text")
        }

        return Name(normal: spelling)
    }

    private func document(_ value: Value) throws -> Place.Document {
        var fields = try Fields(.array([value]), of: "document")

        return Place.Document(
            identity: try fields.maybe { written in
                guard case let .bytes(bytes) = written else {
                    throw ArtifactRefused("'document' writes an identity that is not bytes")
                }

                return Identity(bytes)
            }
        )
    }

    private func leaned(_ value: Value) throws -> [Claim: Place] {
        try list(value, of: "leaned") { entry in
            var fields = try Fields(entry, of: "leaned")
            let claim = Claim(type: try name(fields.next()), contract: try name(fields.next()))
            let where_ = try place(fields.next())

            try fields.end()

            return (claim, where_)
        }
        .reduce(into: [Claim: Place]()) { leaned, entry in leaned[entry.0] = entry.1 }
    }

    private func variable(_ value: Value) throws -> (name: Name, value: Value) {
        var fields = try Fields(value, of: "variable")
        let read = (name: try name(fields.next()), value: try fields.next())

        try fields.end()

        return read
    }
}

private extension ArtifactReader {
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
        case 7: read = .bytes
        case 8: read = .number
        case 9: read = .ranged(try ranged(fields.next()))
        case 10: read = .array(try expression(fields.next()))
        case 11: read = .dictionary(try expression(fields.next()))
        case 12: read = .record(try keyed(fields.next(), of: "record", expression))
        case 13:
            read = .procedure(
                try fields.maybe(signature),
                try purity(fields.next()),
                try isolation(fields.next())
            )

        case 14: read = .variable(try expression(fields.next()))
        case 15: read = .inout(try expression(fields.next()))
        case 16: read = .linear(try expression(fields.next()))
        case 17: read = .consuming(try expression(fields.next()))
        case 18: read = .borrowing(try expression(fields.next()))
        case 19: read = .nullable(try expression(fields.next()))
        case 20: read = .named(try name(fields.next()))
        case 21: read = .parameter(name: try name(fields.next()), constraint: try fields.maybe(name))
        case 22:
            read = .reading(
                of: try name(fields.next()),
                path: try list(fields.next(), of: "path", segment)
            )

        default:
            throw ArtifactRefused("'type' names a kind this reads none of")
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
            throw ArtifactRefused("'range' is over neither whole numbers nor fractions")
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
        default: throw ArtifactRefused("'edge' says neither that its bound is inside nor that it is out")
        }

        try fields.end()

        return held
    }

    func integer(_ value: Value) throws -> Int {
        guard case let .int(integer) = value else {
            throw ArtifactRefused("a number is not written as one")
        }

        return integer
    }

    func fraction(_ value: Value) throws -> Double {
        switch value {
        case let .double(double): return double
        case let .int(integer): return Double(integer)
        default: throw ArtifactRefused("a fraction is not written as a number")
        }
    }

    func text(_ value: Value) throws -> String {
        guard case let .string(text) = value else {
            throw ArtifactRefused("a text is not written as one")
        }

        return text
    }

    func flag(_ value: Value) throws -> Bool {
        guard case let .bool(flag) = value else {
            throw ArtifactRefused("a yes or no is not written as one")
        }

        return flag
    }

    func segment(_ value: Value) throws -> PathSegment {
        var fields = try Fields(value, of: "path segment")
        let read: PathSegment

        switch try fields.tag() {
        case 0: read = .key(try name(fields.next()), optional: try fields.flag())
        case 1: read = .index(try fields.integer(), optional: try fields.flag())
        case 2:
            read = .indexRef(
                try list(fields.next(), of: "path", segment),
                optional: try fields.flag()
            )

        default:
            throw ArtifactRefused("'path segment' steps in a way this reads none of")
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
            candidates: try fields.maybe { written in try list(written, of: "candidates", text) },
            default: try fields.maybe { written in written },
            description: try fields.maybe(text)
        )

        try fields.end()

        return read
    }

    func purity(_ value: Value) throws -> Purity {
        switch try integer(value) {
        case 0: return .unstated
        case 1: return .pure
        default: throw ArtifactRefused("'purity' says neither that it is stated nor that it is pure")
        }
    }

    func isolation(_ value: Value) throws -> Isolation {
        switch try integer(value) {
        case 0: return .unstated
        case 1: return .isolated
        default: throw ArtifactRefused("'isolation' says neither that it is stated nor that it is isolated")
        }
    }

    func failing(_ value: Value) throws -> Failing {
        var fields = try Fields(value, of: "failing")
        let read: Failing

        switch try fields.tag() {
        case 0: read = .unstated
        case 1: read = .these(Set(try list(fields.next(), of: "failing", text)))
        default: throw ArtifactRefused("'failing' says neither nothing nor which failures")
        }

        try fields.end()

        return read
    }
}

private extension ArtifactReader {
    func place(_ value: Value) throws -> Place {
        var fields = try Fields(value, of: "place")
        let held = try document(fields.next())
        let read = Place(try list(fields.next(), of: "place", step), in: held)

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
        default: throw ArtifactRefused("'place step' steps in a way this reads none of")
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
        default: throw ArtifactRefused("'part' names a part this reads none of")
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
        default: throw ArtifactRefused("'condition holder' holds a condition in no way this reads")
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
        default: throw ArtifactRefused("'construct' names a construct this reads none of")
        }

        try fields.end()

        return read
    }

    func reach(_ value: Value) throws -> Leave.Reach {
        switch try integer(value) {
        case 0: return .procedure
        case 1: return .construct
        case 2: return .round
        default: throw ArtifactRefused("'leave' reaches nothing this reads")
        }
    }

    func layout(_ value: Value) throws -> Layout {
        var fields = try Fields(value, of: "layout")
        let read = Layout(
            name: try fields.maybe(name),
            ordered: try list(fields.next(), of: "layout", name)
        )

        try fields.end()

        return read
    }
}

private extension ArtifactReader {
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
        case 7: read = .bytes
        case 8: read = .number
        case 9: read = .ranged(try ranged(fields.next()))
        case 10: read = .array(try lowered(fields.next()))
        case 11: read = .dictionary(try lowered(fields.next()))
        case 12: read = .record(try loweredRecord(fields.next()))
        case 13:
            read = .procedure(
                parameters: try fields.maybe { written in
                    try list(written, of: "parameters") { parameter in
                        var held = try Fields(parameter, of: "parameter")
                        let taken = (
                            name: try name(held.next()),
                            type: try lowered(held.next()),
                            mustBeGiven: try held.flag()
                        )

                        try held.end()

                        return taken
                    }
                },
                returns: try fields.maybe(lowered),
                purity: try purity(fields.next()),
                isolation: try isolation(fields.next())
            )

        case 14: read = .variable(try lowered(fields.next()))
        case 15: read = .inout(try lowered(fields.next()))
        case 16: read = .nullable(try lowered(fields.next()))
        case 17: read = .named(try fields.integer())
        case 18: read = .parameter(label: try name(fields.next()), bound: try fields.maybe(bound))
        case 19:
            read = .reading(
                of: try name(fields.next()),
                path: try list(fields.next(), of: "path", segment)
            )

        case 20: read = .member(try fields.integer())
        case 21: read = .undeclared(label: try fields.text(), refusal: try fields.text())
        default: throw ArtifactRefused("'lowered type' names a kind this reads none of")
        }

        try fields.end()

        return read
    }

    func bound(_ value: Value) throws -> LoweredType.Bound {
        var fields = try Fields(value, of: "bound")
        let read: LoweredType.Bound

        switch try fields.tag() {
        case 0: read = .membership(try fields.integer())
        case 1: read = .contract(try name(fields.next()))
        default: throw ArtifactRefused("'bound' holds a parameter to nothing this reads")
        }

        try fields.end()

        return read
    }

    func loweredRecord(_ value: Value) throws -> LoweredRecord {
        var fields = try Fields(value, of: "record")
        let read = LoweredRecord(
            layout: try layout(fields.next()),
            fields: try list(fields.next(), of: "record", lowered)
        )

        try fields.end()

        return read
    }

    func typeNumbering(_ value: Value) throws -> LoweredTypeNumbering {
        var fields = try Fields(value, of: "type numbering")
        let read = LoweredTypeNumbering(
            types: Set(try list(fields.next(), of: "type numbering", name)),
            memberships: Set(try list(fields.next(), of: "type numbering", name))
        )

        try fields.end()

        return read
    }
}

private extension ArtifactReader {
    func judged(_ value: Value) throws -> Judged {
        var fields = try Fields(value, of: "row")
        let read = Judged(
            label: try name(fields.next()),
            signature: try signature(fields.next()),
            purity: try purity(fields.next()),
            isolation: try isolation(fields.next()),
            failing: try failing(fields.next()),
            sends: try list(fields.next(), of: "row", sent),
            implementation: try implementation(fields.next())
        )

        try fields.end()

        return read
    }

    func implementation(_ value: Value) throws -> Judged.Implementation {
        var fields = try Fields(value, of: "implementation")
        let read: Judged.Implementation

        switch try fields.tag() {
        case 0: read = .body(try body(fields.next()), try frame(fields.next()))
        case 1: read = .native(sending: try list(fields.next(), of: "sending", send))
        default: throw ArtifactRefused("'implementation' answers in a way this reads none of")
        }

        try fields.end()

        return read
    }

    func sent(_ value: Value) throws -> Sent {
        var fields = try Fields(value, of: "send")
        let read = Sent(
            row: try fields.integer(),
            offers: try list(fields.next(), of: "send", integer)
        )

        try fields.end()

        return read
    }

    func send(_ value: Value) throws -> Native.Send {
        var fields = try Fields(value, of: "native send")
        let read = Native.Send(
            position: try fields.integer(),
            selector: try name(fields.next()),
            offers: try list(fields.next(), of: "native send", name)
        )

        try fields.end()

        return read
    }

    func frame(_ value: Value) throws -> Frame {
        var fields = try Fields(value, of: "frame")
        let read = Frame(
            size: try fields.integer(),
            parameters: try list(fields.next(), of: "frame", integer),
            variables: try list(fields.next(), of: "frame") { written in
                var held = try Fields(written, of: "frame variable")
                let taken = (variable: try held.integer(), slot: try held.integer())

                try held.end()

                return taken
            },
            names: try list(fields.next(), of: "frame", name)
        )

        try fields.end()

        return read
    }

    func body(_ value: Value) throws -> Body {
        var fields = try Fields(value, of: "body")
        let read = Body(
            instructions: try list(fields.next(), of: "body", instruction),
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
        case 0: read = .bind(try fields.integer(), settling: try fields.maybe(lowered))
        case 1: read = .declare(try fields.integer(), settling: try fields.maybe(lowered))
        case 2: read = .assign(try address(fields.next()), settling: try fields.maybe(lowered))
        default: throw ArtifactRefused("'binding' binds in a way this reads none of")
        }

        try fields.end()

        return read
    }

    func address(_ value: Value) throws -> Address {
        var fields = try Fields(value, of: "address")
        let read = Address(
            slot: try fields.integer(),
            steps: try list(fields.next(), of: "address", walk)
        )

        try fields.end()

        return read
    }

    func walk(_ value: Value) throws -> Step {
        var fields = try Fields(value, of: "walk")
        let read: Step

        switch try fields.tag() {
        case 0:
            read = .field(try fields.integer(), try name(fields.next()), optional: try fields.flag())

        case 1: read = .key(try name(fields.next()), optional: try fields.flag())
        case 2: read = .index(try fields.integer(), optional: try fields.flag())
        case 3: read = .at(try address(fields.next()), optional: try fields.flag())
        default: throw ArtifactRefused("'walk' steps in a way this reads none of")
        }

        try fields.end()

        return read
    }
}

private extension ArtifactReader {
    func operation(_ value: Value) throws -> Operation {
        var fields = try Fields(value, of: "operation")
        let read: Operation

        switch try fields.tag() {
        case 0: read = .literal(try fields.next())
        case 1: read = .local(try address(fields.next()))
        case 2: read = .array(try list(fields.next(), of: "array", operation))
        case 3: read = .record(try recordOperation(fields.next()))
        case 4:
            read = .closure(
                try fields.integer(),
                captures: try list(fields.next(), of: "captures") { written in
                    var held = try Fields(written, of: "capture")
                    let taken = (try held.integer(), try held.integer())

                    try held.end()

                    return taken
                }
            )

        case 5:
            read = .apply(
                try operation(fields.next()),
                arguments: try list(fields.next(), of: "arguments") { written in
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
                then: try list(fields.next(), of: "then", instruction),
                else: try fields.maybe { written in
                    try list(written, of: "otherwise", instruction)
                }
            )

        case 9:
            read = .loop(
                while: try operation(fields.next()),
                body: try body(fields.next()),
                round: try fields.integer(),
                keeps: try fields.maybe { written in
                    var held = try Fields(written, of: "keeps")
                    let low = try held.integer()
                    let high = try held.integer()

                    try held.end()

                    guard low <= high else {
                        throw ArtifactRefused("'keeps' ends before it begins")
                    }

                    return low ..< high
                }
            )

        case 10:
            read = .attempt(
                try body(fields.next()),
                rescue: try body(fields.next()),
                failure: try fields.integer()
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
            throw ArtifactRefused("'operation' does something this reads none of")
        }

        try fields.end()

        return read
    }

    func recordOperation(_ value: Value) throws -> RecordOperation {
        var fields = try Fields(value, of: "record")
        let read = RecordOperation(
            layout: try layout(fields.next()),
            fields: try list(fields.next(), of: "record", operation)
        )

        try fields.end()

        return read
    }

    func callOperation(_ value: Value) throws -> CallOperation {
        var fields = try Fields(value, of: "call")
        let read = CallOperation(
            procedure: try fields.integer(),
            receiver: try fields.maybe(operation),
            arguments: try list(fields.next(), of: "arguments") { written in
                var held = try Fields(.array([written]), of: "argument")

                return try held.maybe(operation)
            },
            handed: try list(fields.next(), of: "handed") { written in
                var held = try Fields(written, of: "handed")
                let taken = CallOperation.Handed(
                    position: try held.integer(),
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
            arguments: try keyed(fields.next(), of: "arguments", argument),
            calls: try keyed(fields.next(), of: "calls", callOperation)
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
        default: throw ArtifactRefused("'argument' is handed in a way this reads none of")
        }

        try fields.end()

        return read
    }
}
