//
//  StatementReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A statement, written as at most one name plus exactly one construct key.
//
// The envelope carries no modifiers — not `when:` to say whether the statement
// runs, not `rescue:` to say what happens if it fails, because no language
// spells them that way. `some() when x > 0` is not a form anyone writes;
// `if x > 0 { some() }` is, and that is `branch`. Recovery is `attempt` for the
// same reason, plus one of its own: what do-catch guards is a body, and an
// envelope key could only ever guard one statement.
//
// So the envelope is a name, and what a statement binds is one expression.
//
// The name is written three ways, and the spelling is what the statement does
// to it rather than a modifier hung beside it: `id:` fixes a name, `var:`
// introduces one that may be written again, and `set:` writes one declared
// earlier. At most one of the three — none is a statement run for its effect,
// with the answer dropped — and exactly one construct key; the envelope never
// grew back. A leaving construct takes no name at all: it never finishes, so
// the name could never bind.
public struct StatementReader: Decodable {
    private enum EnvelopeKeys: String, CodingKey, CaseIterable {
        case constant = "let"
        case variable = "var"
        case assignment = "set"

        // The binding the key spells, given what it was written with: a name
        // under `let` and `var`, a path under `set`.
        func binding(_ written: String) throws -> Statement.Binding {
            switch self {
            case .constant:
                return .constant(try Name.read(written, at: []))

            case .variable:
                return .variable(try Name.read(written, at: []))

            case .assignment:
                do {
                    return .assignment(try TemplateParser().parseRefPath(written))
                } catch {
                    throw ReadingError("set \(written) — \(error)", at: [])
                }
            }
        }
    }

    // The one key a statement writes its expression under. A construct sits
    // inside it under the construct's own key.
    public static let valueKey: Name = "value"

    public let statement: Statement

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // The name first, so that everything refused below wears it.
        //
        // A walk into an array knows it descended by position and no more. This
        // is the reader that knows the position holds a statement, so the name
        // an author knows it by is this one's to put on. It is read here off
        // the envelope, the one way a name is read at all, rather than worked
        // out from the data again once something has failed — a second reading
        // is a second rule, and two rules for one name is a document called one
        // thing while being refused as another.
        let envelope = try decoder.container(keyedBy: EnvelopeKeys.self)
        let names = EnvelopeKeys.allCases.filter { name in envelope.contains(name) }

        // Only a name that is one. Whether naming itself twice, or with
        // something that is not text, is a refusal is the reading's question
        // and the reading answers it below. What is asked here is what to call
        // the statement while refusing it, and neither of those is a name.
        //
        // The same read as the reading's, through the same door, and lenient
        // only in what it does with a failure: an address that refused on its
        // own would decide which refusal an author sees first, and that is the
        // reading's to decide.
        let id = names.count == 1 ? try? Self.name(names[0], in: envelope) : nil

        do {
            self.statement = try Self.read(from: decoder, envelope: envelope, names: names)
        } catch let refusal as ReadingError {
            throw refusal.addressed(from: Self.address(of: id, in: decoder.steps))
        }
    }

    // MARK: - Public
    // MARK: - Private
    // What a naming key holds, read the one way it is read.
    private static func name(
        _ key: EnvelopeKeys,
        in envelope: KeyedDecodingContainer<EnvelopeKeys>
    ) throws -> String {
        try envelope.decode(String.self, forKey: key)
    }

    // This statement's own address, with the name on it. The position stays:
    // two statements of one name are told apart by it, and a `var` and the
    // `set` that writes it are exactly that.
    private static func address(of id: String?, in steps: [Place.Step]) -> [Place.Step] {
        guard case let .index(position)? = steps.last else { return steps }

        return Array(steps.dropLast()) + [Place.Step.statement(id, at: position)]
    }

    private static func read(
        from decoder: Decoder,
        envelope: KeyedDecodingContainer<EnvelopeKeys>,
        names: [EnvelopeKeys]
    ) throws -> Statement {
        guard let registry = decoder.userInfo[.constructRegistry] as? ConstructRegistry else {
            throw ReadingError(
                "statement decoding requires a ConstructRegistry"
                    + " — decode through Loader",
                at: decoder.steps
            )
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: EnvelopeKeys.allCases.map(\.stringValue) + [Self.valueKey.spelling],
            context: "statement"
        )

        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let valueKey = AnyCodingKey(stringValue: Self.valueKey.spelling)

        guard names.count <= 1 else {
            throw ReadingError(
                "a statement names itself at most once with"
                    + " \(EnvelopeKeys.allCases.map { key in "'\(key.stringValue)'" }.joined(separator: ", "));"
                    + " found: \(names.map { name in "'\(name.stringValue)'" })",
                at: decoder.steps
            )
        }

        let name = names.first
        let binding: Statement.Binding?

        do {
            binding = try name.map { name in try name.binding(try Self.name(name, in: envelope)) }
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

        let inside = try container.superDecoder(forKey: valueKey)
        let expression = try Self.expression(
            in: inside,
            registry: registry,
            boundTo: binding?.spelled
        )

        if binding != nil, expression.alwaysLeaves {
            throw ReadingError(
                "every way through this statement leaves,"
                    + " so its name could never bind — it takes no name",
                at: decoder.steps
            )
        }

        if binding != nil, expression.takesNoName {
            throw ReadingError(
                "a branch answers nothing, so its name"
                    + " could never bind — it takes no name; what an arm"
                    + " keeps is written to an outer variable with 'set'",
                at: decoder.steps
            )
        }

        return Statement(binding: binding, expression: expression)
    }

    // What stands under `value`: a construct, where the record's one key is a
    // construct's, and an expression otherwise. A construct that binds through
    // the statement's name is handed that name.
    private static func expression(
        in decoder: Decoder,
        registry: ConstructRegistry,
        boundTo name: String?
    ) throws -> Expression {
        if
            let keyed = try? decoder.container(keyedBy: AnyCodingKey.self),
            keyed.allKeys.count == 1,
            let written = keyed.allKeys.first?.stringValue,
            let key = try? Name(written),
            key != Self.valueKey,
            let form = registry.form(for: key)
        {
            let inside = try keyed.superDecoder(forKey: AnyCodingKey(stringValue: written))
            let built: any ConstructForm

            do {
                built = try form.init(from: inside)
            } catch let refusal as DecodingError {
                throw ReadingError(refusal, at: inside.steps)
            }

            do {
                return try built.expression(boundTo: name)
            } catch let refusal as ReadingError {
                throw refusal.asked(at: decoder.steps)
            }
        }

        return try ExpressionReader(from: decoder).expression
    }
}
