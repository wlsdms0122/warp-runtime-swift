//
//  StatementReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A statement: at most one naming key and the expression under `value`.
//
//     { let "x" value { … } }
//
// `let` fixes a name, `var` introduces one that may be written again, and
// `set` writes a path into one declared earlier. A statement with none runs
// for its effect and drops the answer. A construct stands under `value` by its
// own key: `{ value { loop { … } } }`.
//
// A name may say what it holds, under `type`. `set` writes a name something
// else declared, so it takes no type of its own.
public struct StatementReader: Decodable {
    enum NamingKeys: String, CodingKey, CaseIterable {
        case constant = "let"
        case variable = "var"
        case assignment = "set"

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // The binding the key spells, given what it was written with: a name
        // under `let` and `var`, a path under `set`. `depth` is how many
        // containers stand around the string.
        func binding(
            _ written: String,
            declaring declared: TypeExpression?,
            at depth: Int
        ) throws -> Statement.Binding {
            switch self {
            case .constant:
                return .constant(try Name.read(written, at: []), declared: declared)

            case .variable:
                return .variable(try Name.read(written, at: []), declared: declared)

            case .assignment:
                do {
                    return .assignment(try PathParser().parse(written, at: depth))
                } catch {
                    throw ReadingError("set \(written): \(error)", at: [])
                }
            }
        }

        // MARK: - Private
    }

    // MARK: - Property
    // The one key a statement writes its expression under. A construct sits
    // inside it under the construct's own key.
    public static let valueKey: Name = "value"

    // What the name says it holds, where it says.
    public static let typeKey: Name = "type"

    let statement: Statement

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // The name first, so that everything refused below wears it.
        //
        // A walk into an array knows it descended by position and no more. This
        // is the reader that knows the position holds a statement, so the name
        // an author knows it by is this one's to put on. It is the binding's
        // name, read here off the naming key the one way a binding is read,
        // rather than worked out from the data again once something has failed.
        let naming = try decoder.container(keyedBy: NamingKeys.self)
        let names = NamingKeys.allCases.filter { name in naming.contains(name) }

        // Only a name that is one: a statement named twice, or with something
        // that is not text, is refused by the reading below, which reads the
        // name the same way and refuses what this lets pass.
        let binding = names.count == 1
            ? try? names[0].binding(Self.name(names[0], in: naming), declaring: nil, at: decoder.steps.count + 1)
            : nil

        do {
            self.statement = try Self.read(from: decoder, naming: naming, names: names)
        } catch let refusal as ReadingError {
            throw refusal.addressed(from: Self.address(of: binding?.name, in: decoder.steps))
        }
    }

    // MARK: - Public
    // MARK: - Private
    // What the statement says its name holds. A `set` reaches a name something
    // else declared, and a statement with no name has none to declare.
    private static func declared(
        in container: KeyedDecodingContainer<AnyCodingKey>,
        named name: NamingKeys?,
        at steps: [Place.Step]
    ) throws -> TypeExpression? {
        let key = AnyCodingKey(stringValue: Self.typeKey.spelling)

        guard container.contains(key) else { return nil }

        guard let name, name != .assignment else {
            throw ReadingError(
                "writes '\(Self.typeKey)', which says what a name holds."
                    + " '\(NamingKeys.constant.stringValue)' and"
                    + " '\(NamingKeys.variable.stringValue)' introduce a name,"
                    + " and this statement introduces none",
                at: steps
            )
        }

        return try container.decode(TypeReader.self, forKey: key).unbounded()
    }

    // What a naming key holds, read the one way it is read.
    private static func name(
        _ key: NamingKeys,
        in naming: KeyedDecodingContainer<NamingKeys>
    ) throws -> String {
        try naming.decode(String.self, forKey: key)
    }

    // This statement's own address, with the name on it. The position stays:
    // two statements of one name are told apart by it, and a `var` and the
    // `set` that writes it are exactly that.
    private static func address(of name: Name?, in steps: [Place.Step]) -> [Place.Step] {
        guard case let .index(position)? = steps.last else { return steps }

        return Array(steps.dropLast()) + [Place.Step.statement(name?.spelling, at: position)]
    }

    private static func read(
        from decoder: Decoder,
        naming: KeyedDecodingContainer<NamingKeys>,
        names: [NamingKeys]
    ) throws -> Statement {
        guard let registry = decoder.userInfo[.constructRegistry] as? ConstructRegistry else {
            throw ReadingError(
                "statement decoding requires a ConstructRegistry."
                    + " Decode through Loader",
                at: decoder.steps
            )
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: NamingKeys.allCases.map(\.stringValue)
                + [Self.valueKey.spelling, Self.typeKey.spelling],
            context: "statement"
        )

        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let valueKey = AnyCodingKey(stringValue: Self.valueKey.spelling)

        guard names.count <= 1 else {
            throw ReadingError(
                "a statement names itself at most once with"
                    + " \(NamingKeys.allCases.map { key in "'\(key.stringValue)'" }.joined(separator: ", "));"
                    + " found: \(names.map { name in "'\(name.stringValue)'" })",
                at: decoder.steps
            )
        }

        let name = names.first
        let declared = try Self.declared(in: container, named: name, at: decoder.steps)
        let binding: Statement.Binding?

        do {
            binding = try name.map { name in
                try name.binding(Self.name(name, in: naming), declaring: declared, at: decoder.steps.count + 1)
            }
        } catch let refusal as ReadingError {
            throw refusal.asked(at: decoder.steps)
        }

        // A variable holding nothing yet is written as the name alone.
        guard container.contains(valueKey) else {
            if case .variable? = binding {
                return Statement(binding: binding, expression: .literal(.null))
            }

            throw ReadingError(
                "a statement writes its expression under '\(Self.valueKey)'",
                at: decoder.steps
            )
        }

        return try Self.statement(
            in: try decoder.descending(to: valueKey),
            registry: registry,
            binding: binding
        )
    }

    // What stands under `value`: a construct, where the mapping's one key is a
    // construct's, and an expression otherwise. A construct is handed the
    // binding the statement was written under and says the statement it is.
    private static func statement(
        in decoder: Decoder,
        registry: ConstructRegistry,
        binding: Statement.Binding?
    ) throws -> Statement {
        if
            let keyed = try? decoder.container(keyedBy: AnyCodingKey.self),
            keyed.allKeys.count == 1,
            let written = keyed.allKeys.first?.stringValue,
            let key = try? Name(written),
            let form = registry.form(for: key)
        {
            let inside = try decoder.descending(to: AnyCodingKey(stringValue: written))
            let built: any ConstructForm

            do {
                built = try form.init(from: inside)
            } catch let refusal as DecodingError {
                throw ReadingError(refusal, at: inside.steps)
            }

            do {
                return try built.statement(binding: binding)
            } catch let refusal as ReadingError {
                throw refusal.asked(at: decoder.steps)
            }
        }

        return Statement(
            binding: binding,
            expression: try ExpressionReader.read(try ValueReader(from: decoder).value, in: decoder)
        )
    }
}
