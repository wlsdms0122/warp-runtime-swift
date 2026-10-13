//
//  TypeWriter.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A type written the way `TypeReader` reads it: a spelling where the type has
// one, and a mapping under the one key its form is read by where it has none.
struct TypeWriter {
    // The bounds a signature's slots write, each beside the first naming of
    // its type parameter, as the reading takes them: the slots in order, at
    // any depth.
    final class Introducing {
        // MARK: - Property
        // What is left to write.
        private(set) var bounds: [Name: Set<Name>]
        private var named: Set<Name> = []

        // MARK: - Initializer
        init(_ bounds: [Name: Set<Name>]) {
            self.bounds = bounds
        }

        // MARK: - Public
        // The bound written beside this naming, at the first one only.
        func bound(at name: Name) -> Set<Name>? {
            guard named.insert(name).inserted else { return nil }

            return bounds.removeValue(forKey: name)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // Who reads the spelling back, which says what a declared name written
    // short stands for.
    let readBy: Notation

    // MARK: - Initializer
    // MARK: - Public
    // A spelling is kept only where the reading takes it back as this type.
    func value(of type: TypeExpression) throws -> Value {
        try value(of: type, introducing: nil)
    }

    // The same in a signature's slot, where a bound stands beside the first
    // naming of its type parameter.
    func value(of type: TypeExpression, introducing: Introducing?) throws -> Value {
        try checked(try form(of: type, introducing: introducing), as: type)
    }

    // A declared type: a struct under `struct`, its fields beside their
    // types, the type parameters it takes beside their bounds where it takes
    // any, and an alias as the type it stands for.
    func value(of declared: TypeDeclaration) throws -> Value {
        switch declared {
        case let .struct(fields, typeParameters, bounds):
            var written: [Name: Value] = [TypeDeclarationReader.structKey: .dictionary(try fields.mapValues(value(of:)))]

            if !typeParameters.isEmpty || !bounds.isEmpty {
                written[TypeDeclarationReader.typeParametersKey] = try introduced(typeParameters, bounds: bounds)
            }

            return .dictionary(written)

        case let .alias(type):
            return try value(of: type)
        }
    }

    // Names a list introduces, a struct's type parameters or the types a
    // contract asks, each beside the contracts it is bounded by, joined with
    // `&`. A bound on a name the list does not hold has nowhere to stand.
    func introduced(_ names: [Name], bounds: [Name: Set<Name>]) throws -> Value {
        if let unwritten = Set(bounds.keys).subtracting(names).min() {
            throw WritingError("bounds '\(unwritten)', which the list does not hold, and a bound stands beside its name")
        }

        return .array(
            names.map { name in
                guard let contracts = bounds[name] else { return .string(name.spelling) }

                return .string("\(name.spelling): \(Self.joined(contracts))")
            }
        )
    }

    // What a signature bounds that it does not introduce, an associated type
    // of one of its type parameters, under its label, or nothing where it
    // bounds none.
    func labeled(_ bounds: [Name: Set<Name>]) -> Value? {
        guard !bounds.isEmpty else { return nil }

        return .dictionary(bounds.mapValues { contracts in .string(Self.joined(contracts)) })
    }

    // MARK: - Private
    // A bound's contracts, in one order.
    private static func joined(_ contracts: Set<Name>) -> String {
        contracts.sorted().map(\.spelling).joined(separator: " & ")
    }

    // A written type, where a spelling is one the reading takes back as the
    // type.
    private func checked(_ written: Value, as type: TypeExpression) throws -> Value {
        guard case let .string(spelling) = written else { return written }

        let read: TypeExpression

        do {
            read = try TypeReader.reading(spelling, in: readBy).bounded.type
        } catch {
            throw WritingError("the type is written '\(spelling)', which the reading refuses: \(error)")
        }

        guard read == type else {
            throw WritingError(
                "the type is written '\(spelling)', which the reading takes as \(read.rendered),"
                    + " and a document has no way to tell the two apart"
            )
        }

        return written
    }

    // What a type is written as, before the reading is asked about it.
    private func form(of type: TypeExpression, introducing: Introducing?) throws -> Value {
        switch type {
        case .any: return .string(TypeSpelling.any.spelling)
        case .never: return .string(TypeSpelling.never.spelling)
        case .null: return .string(TypeSpelling.null.spelling)
        case .bool: return .string(TypeSpelling.bool.spelling)
        case .int: return .string(TypeSpelling.int.spelling)
        case .double: return .string(TypeSpelling.double.spelling)
        case .string: return .string(TypeSpelling.string.spelling)
        case .selfType: return .string(TypeSpelling.selfType.spelling)

        // What a struct is applied to is written between its brackets, and
        // each of those has a spelling: a procedure type that writes its
        // signature reaches one through a declared name.
        case let .named(name, arguments):
            guard !arguments.isEmpty else { return .string(name.spelling) }

            let spelled = try arguments.map { argument in
                try self.named(
                    argument,
                    at: "between a struct's brackets. A procedure type is declared and written by its name",
                    introducing: introducing
                )
            }

            return .string("\(name.spelling)<\(spelled.joined(separator: ", "))>")

        // No document spells this. It is a type the build worked out from a
        // body, and the load refuses one written into a declaration; a draft
        // holding one is said rather than written as something else.
        case let .projection(of, path):
            throw WritingError(
                "`\(TypeSpelling.some) \(Path([.name(of)] + path.segments).rendered)` is a type"
                    + " the build read out of a body,"
                    + " and no document writes one. A declaration says what a call"
                    + " fills"
            )

        // Its bound beside it where the slots first name it.
        case let .parameter(name):
            guard let contracts = introducing?.bound(at: name) else {
                return .string("\(TypeSpelling.some) \(name)")
            }

            return .string("\(TypeSpelling.some) \(name): \(Self.joined(contracts))")

        case .associatedType:
            return .string(type.rendered)

        case let .composition(names):
            return .string(names.sorted().map(\.spelling).joined(separator: " & "))

        // Written as the name it is where the element has one, and under its
        // own key where the element has none. An array of procedures is the
        // case with none.
        case let .array(element):
            let inner = try form(of: element, introducing: introducing)

            guard case let .string(spelling) = inner else {
                return .dictionary([Name(normal: TypeReader.Holding.array.rawValue): try checked(inner, as: element)])
            }

            return .string("\(TypeReader.Holding.array.spelling)<\(spelling)>")

        case let .dictionary(key, value):
            let keyForm = try form(of: key, introducing: introducing)
            let valueForm = try form(of: value, introducing: introducing)

            guard case let .string(keySpelling) = keyForm, case let .string(valueSpelling) = valueForm else {
                return .dictionary([
                    Name(normal: TypeReader.Holding.dictionary.rawValue): .dictionary([
                        TypeReader.DictionaryTypeReader.CodingKeys.key.name: try checked(keyForm, as: key),
                        TypeReader.DictionaryTypeReader.CodingKeys.value.name: try checked(valueForm, as: value)
                    ])
                ])
            }

            return .string("\(TypeReader.Holding.dictionary.spelling)<\(keySpelling), \(valueSpelling)>")

        // Spelled with the trailing `?` the reader takes, which is why the
        // declared half has to have a name of its own.
        case let .nullable(inner):
            return .string(
                "\(try named(inner, at: "before `?`. A struct is declared and written by its name, like `Task?`", introducing: introducing))?"
            )

        // Both marks are written the same way, so the writing is said once
        // below. They are matched one to a case because the mark a case carries
        // is what the writing needs and a pattern cannot hand it over.
        case let .variable(inner):
            return try value(of: inner, under: .variable, introducing: introducing)

        case let .inout(inner):
            return try value(of: inner, under: .inout, introducing: introducing)

        case let .procedure(type, constness, isolation):
            guard let type else { return .string(TypeReader.procedureSpelling(constness, isolation, as: .name)) }

            let spelling = TypeReader.procedureSpelling(constness, isolation, as: .key)

            var written: [Name: Value] = [:]

            if !type.parameters.isEmpty {
                written[TypeReader.ProcedureTypeReader.CodingKeys.parameters.name] = .array(
                    try type.parameters.map { parameter in try value(of: parameter, introducing: introducing) }
                )
            }

            if let returns = type.returns {
                written[TypeReader.ProcedureTypeReader.CodingKeys.returns.name] = try value(of: returns, introducing: introducing)
            }

            if case let .these(failures) = type.failing {
                written[TypeReader.ProcedureTypeReader.CodingKeys.failing.name] = .array(
                    failures.sorted().map(Value.string)
                )
            }

            return .dictionary([try Name(spelling): .dictionary(written)])
        }
    }

    // A marked slot is written with the mark in front of the inner type,
    // whichever form that type takes: a bare name, or a procedure form under
    // its one key.
    private func value(of inner: TypeExpression, under mark: SlotMark, introducing: Introducing?) throws -> Value {
        switch try form(of: inner, introducing: introducing) {
        case let .string(written):
            return .string(mark.marking(written))

        case let .dictionary(form) where form.count == 1
            && ((try? form.named()[0].name).map(TypeReader.readsAsAProcedure) ?? false):
            // A key carries one mark, and a key carrying two reads back as no
            // type form.
            if let inside = SlotMark.marked(inner) {
                throw WritingError(
                    "`\(inside.word)` is written inside `\(mark.word)`, and a procedure's key"
                        + " carries one mark"
                )
            }

            return .dictionary([
                try Name(mark.marking(try form.named()[0].name.spelling)): form.entries[0].value
            ])

        default:
            throw WritingError(
                "`\(mark.word)` is written in front of a type name, and"
                    + " \(inner.rendered) is not written as one. Declare it under a"
                    + " name and write `\(mark.word)` on the name"
            )
        }
    }

    // Only a type with a name of its own takes a `?` after it, said with the
    // place the author wrote, so the refusal points at their text.
    private func named(_ type: TypeExpression, at context: String, introducing: Introducing?) throws -> String {
        guard case let .string(name) = try form(of: type, introducing: introducing) else {
            throw WritingError("only a type with a name is written \(context)")
        }

        return name
    }
}
