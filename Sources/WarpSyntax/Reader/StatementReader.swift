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
        case id
        case variable = "var"
        case assignment = "set"

        // The binding the key spells, given what it was written with: a name
        // under `id` and `var`, a path under `set`.
        func binding(_ written: String) throws -> Statement.Binding {
            switch self {
            case .id:
                return .constant(written)

            case .variable:
                return .variable(written)

            case .assignment:
                do {
                    return .assignment(try TemplateParser().parseRefPath(written))
                } catch {
                    throw ReadingError("set \(written) — \(error)", at: [])
                }
            }
        }
    }

    // MARK: - Property
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
            known: EnvelopeKeys.allCases.map(\.stringValue) + registry.keys,
            context: "statement"
        )

        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let found = registry.keys.filter { key in
            container.contains(AnyCodingKey(stringValue: key))
        }

        // The naming keys were read by presence and not by decoding — `id:
        // null` is a key written with no name in it, and reading it as "no
        // naming key" would make a failed name and an omitted one the same
        // document.
        guard names.count <= 1 else {
            throw ReadingError(
                "a statement names itself at most once with"
                    + " \(EnvelopeKeys.allCases.map { key in "'\(key.stringValue)'" }.joined(separator: ", "));"
                    + " found: \(names.map { name in "'\(name.stringValue)'" })",
                at: decoder.steps
            )
        }

        // A `var` may stand alone: it introduces a name with nothing in it
        // yet, and a name holding nothing holds null. The other spellings say
        // something about a construct, so they still require one — and the
        // one-name rule above has already spoken, so "alone" is one question.
        if found.isEmpty, names == [.variable] {
            return Statement(
                binding: .variable(try Self.name(.variable, in: envelope)),
                expression: .literal(.null)
            )
        }

        guard found.count == 1, let key = found.first else {
            throw ReadingError(
                "a statement must declare exactly one construct key"
                    + " (\(registry.keys.joined(separator: "/")));"
                    + " found: \(found)",
                at: decoder.steps
            )
        }

        guard let form = registry.form(for: key) else {
            throw ReadingError(
                "no construct registered for key '\(key)'",
                at: decoder.steps
            )
        }

        let name = names.first
        let id = try name.map { name in try Self.name(name, in: envelope) }
        let binding: Statement.Binding?

        do {
            binding = try name.map { name in try name.binding(try Self.name(name, in: envelope)) }
        } catch let refusal as ReadingError {
            throw refusal.asked(at: decoder.steps)
        }
        let inside = try container.superDecoder(forKey: AnyCodingKey(stringValue: key))
        let built: any ConstructForm
        let expression: Expression

        do {
            built = try form.init(from: inside)
        } catch let refusal as DecodingError {
            // A form written outside this package reads with `Codable`'s
            // refusal, which carries `Codable`'s address. The walk's own is
            // right here, so it is put on rather than the one a coding key
            // would spell.
            throw ReadingError(refusal, at: inside.steps)
        }

        do {
            expression = try built.expression(boundTo: id)
        } catch let refusal as ReadingError {
            // A form lowering what it read is past every decoder, so a refusal
            // from there says nothing about where it is. This statement is
            // where it is, and this is what is holding that.
            throw refusal.asked(at: decoder.steps)
        }

        // A statement that leaves never finishes, so a name on one promises a
        // binding that cannot happen. Only the structure a document shows is
        // judged here — a call whose word never answers is a fact about the
        // link, and the linker refuses it where the signature is known. The
        // sentence is the Validator's, word for word: one rule, one wording,
        // whichever door a statement came through.
        if id != nil, expression.alwaysLeaves {
            throw ReadingError(
                "every way through this statement leaves,"
                    + " so its name could never bind — it takes no name",
                at: decoder.steps
            )
        }

        // The other nameless family, held here for every form that builds a
        // branch — a notation's own spelling included — so no form has to
        // remember the rule itself.
        if id != nil, expression.takesNoName {
            throw ReadingError(
                "a branch answers nothing, so its name"
                    + " could never bind — it takes no name; what an arm"
                    + " keeps is written to an outer variable with 'set'",
                at: decoder.steps
            )
        }

        return Statement(binding: binding, expression: expression)
    }
}
