//
//  Writer.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// The other direction: a program written back out as data. `Loader` reads a
// document and answers with a module; this takes a module and answers with the
// document that would load into it, so a program built in Swift can leave the
// machine that built it. Only the types that stand one to one with the
// language are written, so a program that arrived spelled is written back
// unspelled, and it means the same thing.
public struct Writer: Sendable {
    // MARK: - Property
    public let registry: ConstructRegistry

    // Which notation the result is read by: the far side, not this side. It
    // decides whether a parameter is written as one pair, which only a
    // notation that reads pairs takes back. A loader's notation says what an
    // input is written in, and this says who the output is for; a front end is
    // where the two differ.
    public let readBy: Notation

    // MARK: - Initializer
    // Canonical by default, because a document that travels is read by a
    // runtime, and a runtime has no notation.
    public init(registry: ConstructRegistry = .standard, readBy: Notation = .canonical) {
        self.registry = registry
        self.readBy = readBy
    }

    // MARK: - Public
    public func value(of module: Module) throws -> Value {
        try value(of: module.draft)
    }

    // A draft and not only a module, because what a document *is* is answered by
    // writing it back out, and that answer is owed for a text whose program does
    // not hold together. Nothing here judges.
    public func value(of draft: Draft) throws -> Value {
        // The version and the imports are written every time: the version is
        // this writer's, and the imports are what the program takes from its
        // link. A draft that claimed none is written with what it uses.
        var written: [Name: Value] = [
            Module.versionKey: .int(ModuleReader.version),
            ModuleReader.CodingKeys.imports.name: .array(
                ((draft.imports ?? draft.uses).map(\.spelling) + draft.importedClaims.map(\.spelling))
                    .sorted { one, other in one.utf8.lexicographicallyPrecedes(other.utf8) }
                    .map(Value.string)
            )
        ]

        // A member is written where its type is given it, so what stands at the
        // top is the rest.
        let procedures = draft.procedures.filter { spelling, _ in draft.member(spelling) == nil }

        if !procedures.isEmpty {
            written[ModuleReader.CodingKeys.procedures.name] = .dictionary(try procedures.mapValues(value(of:)))
        }

        if let description = draft.description {
            written[ModuleReader.CodingKeys.description.name] = .string(description)
        }

        // What the document gives a type stands in the struct's declaration
        // where the document declares the struct, and in an extension of the
        // type otherwise.
        let receiving = Set(draft.claims.keys).union(draft.members.keys).union(draft.typeMembers.keys)

        if !draft.types.isEmpty {
            written[ModuleReader.CodingKeys.types.name] = .dictionary(
                try draft.types.reduce(into: [Name: Value]()) { types, entry in
                    let (type, declared) = entry

                    let written = try value(of: declared)

                    guard case .struct = declared, case let .dictionary(fields) = written else {
                        types[type] = written

                        return
                    }

                    types[type] = .dictionary(
                        try given(Head(type), in: draft).reduce(fields) { fields, entry in
                            fields.writing(entry.key, with: entry.value)
                        }
                    )
                }
            )
        }

        let extended = receiving.filter { head in
            guard head.isBare, case .struct? = draft.types[head.type] else { return true }

            return false
        }

        if !extended.isEmpty {
            written[ModuleReader.CodingKeys.extensions.name] = .dictionary(
                try extended.reduce(into: [Name: Value]()) { extensions, head in
                    extensions[try key(of: head)] = .dictionary(try given(head, in: draft))
                }
            )
        }

        if !draft.contracts.isEmpty {
            written[ModuleReader.CodingKeys.contracts.name] = .dictionary(
                try draft.contracts.mapValues { contract in
                    var asking: [Name: Value] = [:]

                    if !contract.types.isEmpty || !contract.bounds.isEmpty {
                        asking[ContractReader.CodingKeys.types.name] = try TypeWriter(readBy: readBy)
                            .introduced(contract.types.sorted(), bounds: contract.bounds)
                    }

                    guard !contract.procedures.isEmpty else { return .dictionary(asking) }

                    asking[ContractReader.CodingKeys.procedures.name] = .dictionary(
                        try contract.procedures.mapValues { asked in
                            var written = try fields(of: asked.signature)

                            if asked.constness == .const {
                                written[ContractProcedureReader.CodingKeys.const.name] = .bool(true)
                            }

                            if asked.isolation == .isolated {
                                written[ContractProcedureReader.CodingKeys.isolated.name] = .bool(true)
                            }

                            if !asked.failing.isEmpty {
                                written[ContractProcedureReader.CodingKeys.failing.name] = .array(
                                    asked.failing.sorted().map(Value.string)
                                )
                            }

                            return .dictionary(written)
                        }
                    )

                    return .dictionary(asking)
                }
            )
        }

        if !draft.constants.isEmpty {
            written[ModuleReader.CodingKeys.const.name] = .dictionary(
                try draft.constants.mapValues { constant in try value(of: constant) }
            )
        }

        if !draft.variables.isEmpty {
            written[ModuleReader.CodingKeys.variables.name] = .dictionary(
                try draft.variables.mapValues { variable -> Value in
                    guard let declared = variable.declared else { return try value(of: variable.start) }

                    return .dictionary([
                        VariableReader.typeKey: try value(of: declared),
                        VariableReader.valueKey: try value(of: variable.start)
                    ])
                }
            )
        }

        return .dictionary(written)
    }

    public func value(of procedure: Procedure) throws -> Value {
        // A body is what a document declares. A procedure backed by native code has
        // nothing a document could carry, and writing its name alone would make
        // a document that loads into something else.
        guard case let .body(block) = procedure.implementation else {
            throw WritingError(
                "a procedure implemented in native code has no document."
                    + " What the host brings is declared in a module it assembles into the link"
            )
        }

        var written: [Name: Value] = [:]

        if let description = procedure.description {
            written[ProcedureReader.CodingKeys.description.name] = .string(description)
        }

        // Written where it says something a reader would not fill in.
        if procedure.access != .internal {
            written[ProcedureReader.CodingKeys.access.name] = .string(procedure.access.rawValue)
        }

        written.merge(try fields(of: procedure.signature)) { one, _ in one }
        written.merge(try fields(of: block, in: nil)) { one, _ in one }

        return .dictionary(written)
    }

    public func value(of type: TypeExpression) throws -> Value {
        try TypeWriter(readBy: readBy).value(of: type)
    }

    public func value(of declared: TypeDeclaration) throws -> Value {
        try TypeWriter(readBy: readBy).value(of: declared)
    }

    public func value(of parameter: Parameter) throws -> Value {
        try value(of: parameter, introducing: nil)
    }

    // Where the two positions a document writes an expression in stop being the
    // same. A statement is a name and one construct, so every construct the language has
    // can be written there; inside another expression there is no name to give, so
    // only the types that need none can.
    public func value(of statement: Statement) throws -> Value {
        var written: [Name: Value] = [:]

        if let binding = statement.binding {
            written[key(of: binding)] = .string(try spelling(of: binding))

            if let declared = binding.declared {
                written[StatementReader.typeKey] = try value(of: declared)
            }
        }

        // A variable holding null is what a bare `var` introduces, and the bare
        // spelling is the one canonical writing of that fact.
        if
            case .variable? = statement.binding,
            case .literal(.null) = statement.expression
        {
            return .dictionary(written)
        }

        let (key, body) = try construct(of: statement.expression)

        written[StatementReader.valueKey] = key == StatementReader.valueKey ? body : .dictionary([key: body])

        return .dictionary(written)
    }

    // An expression as a document writes it: a scalar as itself, an array as
    // the array of what it holds, and anything else under the one key its
    // form is read by.
    public func value(of expression: Warp.Expression) throws -> Value {
        switch expression {
        case let .literal(value):
            return try literal(value)

        case let .reference(path):
            return .dictionary([ExpressionTag.reference.key: .string(try spelling(of: path))])

        case let .array(elements):
            return .array(try elements.map { element in try value(of: element) })

        case let .struct(fields):
            let written = Value.Dictionary(try fields.mapValues { field in try value(of: field) })

            return .dictionary([ExpressionTag.struct.key: .dictionary(written)])

        case let .dictionary(entries):
            return .dictionary([
                ExpressionTag.dictionary.key: .array(
                    try entries.map { entry in .array([try value(of: entry.key), try value(of: entry.value)]) }
                )
            ])

        case let .closure(procedure):
            return .dictionary([ExpressionTag.closure.key: try value(of: procedure)])

        // The mark rides on the key, the way `?.` rides on a segment: one
        // spelling says the mismatch refuses and the other says it reads as
        // null, and the type itself is written once either way.
        case let .cast(read, type, optional):
            return .dictionary([
                (optional ? ExpressionTag.optionalCast : ExpressionTag.cast).key: .dictionary([
                    ExpressionReader.subjectKey: try value(of: read),
                    ExpressionReader.typeKey: try value(of: type)
                ])
            ])

        case let .call(call):
            return .dictionary([ExpressionTag.call.key: try self.call(of: call)])

        case let .apply(callee, arguments):
            return .dictionary([ExpressionTag.call.key: try self.call(of: callee, handing: arguments)])

        // Everything left is a construct, and this notation spells constructs
        // in statement position only. Some of them need to be there (a loop and
        // an attempt each bind a name inside themselves and take it from the
        // statement they are written as) and the rest are there because the
        // expression grammar is a fixed set and they are not in it.
        default:
            throw WritingError(
                "\(Self.construct(of: expression)) has no spelling where a value is wanted."
                    + " This notation writes it as a statement"
            )
        }
    }

    // MARK: - Private
    // What a document gives a type: the contracts it says the type answers,
    // and its members, each under the name it has there.
    private func given(_ head: Head, in draft: Draft) throws -> [Name: Value] {
        var written: [Name: Value] = [:]

        if let contracts = draft.claims[head], !contracts.isEmpty {
            written[ExtensionReader.CodingKeys.satisfies.name] = .array(
                contracts.sorted().map { name in .string(name.spelling) }
            )
        }

        if let types = draft.typeMembers[head], !types.isEmpty {
            written[ExtensionReader.CodingKeys.types.name] = .dictionary(try types.mapValues(value(of:)))
        }

        if let members = draft.members[head], !members.isEmpty {
            written[ExtensionReader.CodingKeys.procedures.name] = .dictionary(
                try members.reduce(into: [Name: Value]()) { procedures, member in
                    guard let procedure = draft.procedures[member.spelled(under: head.type)] else { return }

                    procedures[member] = try value(of: procedure)
                }
            )
        }

        return written
    }

    // The key an extension is written under: the head's spelling, kept only
    // where the reading takes it back as this head.
    private func key(of head: Head) throws -> Name {
        let spelling = head.spelling
        let read: Head

        do {
            read = try TypeReader.head(spelling.spelling, in: readBy)
        } catch {
            throw WritingError("the extension is written '\(spelling)', which the reading refuses: \(error)")
        }

        guard read == head else {
            throw WritingError(
                "the extension is written '\(spelling)', which the reading takes as '\(read.spelling)',"
                    + " and a document has no way to tell the two apart"
            )
        }

        return spelling
    }
    // The keys a block writes, with whoever reads it asked whether an empty
    // `body` is written or dropped. A rescue and a procedure are read by their
    // own readers, which take `body` as a key that may be absent, and say
    // `nil`.
    private func fields(
        of block: Block,
        in form: (any ConstructForm.Type)?
    ) throws -> [Name: Value] {
        var written: [Name: Value] = [:]

        if form?.requiresBody == true || !block.body.statements.isEmpty {
            written[BlockReader.CodingKeys.body.name] = .array(try block.body.statements.map(value(of:)))
        }

        if let result = block.result {
            written[BlockReader.CodingKeys.result.name] = try value(of: result)
        }

        return written
    }

    // A parameter, its type written as a slot's, where a bound stands beside
    // the first naming of a type parameter.
    private func value(of parameter: Parameter, introducing: TypeWriter.Introducing?) throws -> Value {
        var written: [Name: Value] = [ParameterReader.CodingKeys.name.name: .string(parameter.name.spelling)]

        if parameter.type != .any {
            written[ParameterFieldsReader.CodingKeys.type.name] = try TypeWriter(readBy: readBy)
                .value(of: parameter.type, introducing: introducing)
        }

        if let description = parameter.description {
            written[ParameterFieldsReader.CodingKeys.description.name] = .string(description)
        }

        // A struct holding nothing but the name is one pair, which a notation
        // offering the pair form reads as a name and its type. There it is
        // written as the pair holding nothing.
        guard written.count > 1 || !readBy.pairedParameter else {
            return .dictionary([parameter.name: .dictionary([:])])
        }

        return .dictionary(written)
    }

    // A signature is written flat into whatever declares it. A procedure and a
    // contract's procedure both spell it as their own keys rather than nesting
    // it.
    //
    // A type parameter's bound stands beside the first naming of it the
    // slots write, and an associated type's under `bounds`.
    private func fields(of signature: Signature) throws -> [Name: Value] {
        var written: [Name: Value] = [:]
        let introducing = TypeWriter.Introducing(signature.bounds.filter { label, _ in label.associated == nil })

        if !signature.parameters.isEmpty {
            written[SignatureFieldsReader.CodingKeys.parameters.name] = .array(
                try signature.parameters.map { parameter in try value(of: parameter, introducing: introducing) }
            )
        }

        if let returns = signature.returns {
            written[SignatureFieldsReader.CodingKeys.returns.name] = try TypeWriter(readBy: readBy)
                .value(of: returns, introducing: introducing)
        }

        if let unwritten = introducing.bounds.keys.sorted().first {
            throw WritingError("bounds '\(unwritten)', which no slot names, and a bound stands beside its first naming")
        }

        if let bounds = TypeWriter(readBy: readBy).labeled(signature.bounds.filter { label, _ in label.associated != nil }) {
            written[SignatureFieldsReader.CodingKeys.bounds.name] = bounds
        }

        if !signature.sameTypes.isEmpty {
            written[SignatureFieldsReader.CodingKeys.sameTypes.name] = .dictionary(
                try signature.sameTypes.mapValues(value(of:))
            )
        }

        return written
    }

    // A construct key and what goes under it. The key comes from the registry
    // rather than from the form, because a notation may have respelled it or
    // given it up.
    private func construct(of expression: Warp.Expression) throws -> (Name, Value) {
        switch expression {
        // A call is a tag, read where a statement's value is the way it is
        // everywhere else, so no table respells it.
        case let .call(call):
            return (ExpressionTag.call.key, try self.call(of: call))

        case let .apply(callee, arguments):
            return (ExpressionTag.call.key, try self.call(of: callee, handing: arguments))

        case let .block(block):
            return (try spelling(BlockForm.self), .dictionary(try fields(of: block, in: BlockForm.self)))

        case let .conditional(condition, then, otherwise):
            var written: [Name: Value] = [
                ConditionalForm.CodingKeys.when.name: try value(of: condition),
                ConditionalForm.CodingKeys.then.name: .array(try then.statements.map(value(of:)))
            ]

            // An empty `else` runs what no `else` runs, so it is written the
            // one way: not at all.
            if let otherwise, !otherwise.statements.isEmpty {
                written[ConditionalForm.CodingKeys.else.name] = .array(try otherwise.statements.map(value(of:)))
            }

            return (try spelling(ConditionalForm.self), .dictionary(written))

        case let .loop(condition, body):
            var written: [Name: Value] = [
                LoopForm.CodingKeys.while.name: try value(of: condition)
            ]

            written.merge(try fields(of: body, in: LoopForm.self)) { one, _ in one }

            return (try spelling(LoopForm.self), .dictionary(written))

        case let .leave(leave):
            let target = leave.target.map { name in Value.string(name.spelling) } ?? .null

            switch leave.reach {
            case .procedure:
                var carried = Value.null

                if let written = leave.value {
                    carried = try value(of: written)
                }

                return (try spelling(ReturnForm.self), carried)

            case .construct:
                return (try spelling(BreakForm.self), target)

            case .round:
                return (try spelling(ContinueForm.self), target)
            }

        case let .attempt(attempted, rescue):
            var written = try fields(of: attempted, in: AttemptForm.self)

            written[AttemptForm.CodingKeys.rescue.name] = .dictionary(try fields(of: rescue, in: nil))

            return (try spelling(AttemptForm.self), .dictionary(written))

        // Whatever is left needs no name, so it is written as the expression it
        // is under the key that says "this statement is just a value".
        default:
            return (StatementReader.valueKey, try value(of: expression))
        }
    }

    // A call of a value, under the same key a call of a declaration is. A
    // string under `procedure` reads back as a name, so a value that is
    // literal text has no spelling there.
    private func call(of callee: Warp.Expression, handing arguments: [Warp.Expression]) throws -> Value {
        if case .literal(.string) = callee {
            throw WritingError("a call of literal text has no spelling: text under `procedure` names a declaration")
        }

        var written: [Name: Value] = [CallForm.CodingKeys.procedure.name: try value(of: callee)]

        if !arguments.isEmpty {
            written[CallForm.CodingKeys.arguments.name] = .array(
                try arguments.map { argument in try value(of: argument) }
            )
        }

        return .dictionary(written)
    }

    private func call(of call: Call) throws -> Value {
        var written: [Name: Value] = [CallForm.CodingKeys.procedure.name: .string(call.selector.spelling)]

        if !call.arguments.isEmpty {
            written[CallForm.CodingKeys.arguments.name] = .array(
                try call.arguments.map { argument in try value(of: argument) }
            )
        }

        return .dictionary(written)
    }

    private func spelling(_ form: any ConstructForm.Type) throws -> Name {
        guard let key = registry.key(for: form) else {
            throw WritingError(
                "this notation registers no key for \(form). A construct it gave"
                    + " the key up for is one it can no longer write"
            )
        }

        return key
    }

    private func key(of binding: Statement.Binding) -> Name {
        switch binding {
        case .constant: StatementReader.NamingKeys.constant.name
        case .variable: StatementReader.NamingKeys.variable.name
        case .assignment: StatementReader.NamingKeys.assignment.name
        }
    }

    // What a naming key holds: the name, or the path a `set` writes.
    private func spelling(of binding: Statement.Binding) throws -> String {
        switch binding {
        case let .constant(name, _), let .variable(name, _):
            return name.spelling

        case let .assignment(path):
            return try spelling(of: path)
        }
    }

    // A path as the reading takes it back. A name holding what a path is
    // spelled with (`.`, `[`) is one segment here and reads back as others.
    private func spelling(of path: Path) throws -> String {
        let spelled = path.rendered

        guard (try? PathParser().parse(spelled)) == path else {
            throw WritingError(
                "'\(spelled)' reads back as another path. A name in it holds what"
                    + " a path is spelled with, and a document has no way to tell"
                    + " them apart"
            )
        }

        return spelled
    }

    // Data as a document writes it: a map as the map literal that makes it.
    private func literal(_ value: Value) throws -> Value {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes:
            return value

        // A draft is written as it is, held to no rule, so a struct is
        // written with its name and reads back as the literal it was.
        case .struct:
            return value

        case let .array(elements):
            return .array(try elements.map(literal))

        // A map is written as the map literal that makes it, its entries in
        // key order.
        case let .dictionary(held):
            return .dictionary([
                ExpressionTag.dictionary.key: .array(
                    try held.entries.map { entry in .array([try literal(entry.key), try literal(entry.value)]) }
                )
            ])

        case .procedure:
            throw WritingError(
                "a procedure closed over a scope is not data, and a document holds data"
            )
        }
    }

    private static func construct(of expression: Warp.Expression) -> String {
        switch expression {
        case .leave: "leaving"
        case .literal: "a literal"
        case .reference: "a reference"
        case .array: "an array"
        case .struct: "a struct"
        case .dictionary: "a map"
        case .closure: "a closure"
        case .apply: "a call of a value"
        case .block: "a block"
        case .conditional: "a conditional"
        case .loop: "a loop"
        case .attempt: "an attempt"
        case .call: "a call"
        case .cast: "a cast"
        }
    }
}
