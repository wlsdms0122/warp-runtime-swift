//
//  ModuleReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A document, which is a module and not a procedure: what it imports and
// what it declares. Which procedure runs is named when a run starts.
public struct ModuleReader: Decodable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case imports
        case description
        case types
        case contracts
        case satisfies
        case const
        case variables = "var"
        case procedures
    }

    // MARK: - Property
    // Which types a reader has to understand. It goes up when a type is added
    // or an existing one changes what it means, and does not move for a new
    // procedure, which is vocabulary. Every document says it.
    public static let version = 1

    // What the document declares, unjudged. Reading and checking are two
    // questions and only one of them is about the program: a text nobody can
    // run is still a text, and still that one, so the reading answers for it
    // and `Module` is where it is held to anything.
    public let draft: Draft

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try Self.checkVersion(in: decoder)

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            extra: [Module.versionKey.spelling],
            context: "module"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let notation = decoder.notation

        self.draft = Draft(
            description: try container.decodeIfPresent(String.self, forKey: .description),
            imports: try Self.imports(in: container),
            types: try Self.record(TypeReader.self, in: container, forKey: .types)
                .mapValues(\.type),
            contracts: try Self.record(ContractReader.self, in: container, forKey: .contracts)
                .mapValues(\.procedures),
            // In key order, so that the same refusal comes first every run.
            claims: try Self.record([String].self, in: container, forKey: .satisfies)
                .sorted { one, other in one.key < other.key }
                .reduce(into: [Name: Set<Name>]()) { claims, entry in
                    // The key is the type claiming, written as the document
                    // spells it; the contracts it claims are a set of names,
                    // and order and repeats are the one spelling's to hold.
                    let steps: [Place.Step] = [.key(CodingKeys.satisfies.rawValue), .key(entry.key.spelling)]

                    claims[entry.key] = Set(
                        try entry.value.map { spelled in notation.qualified(try Name.read(spelled, at: steps), as: .type) }
                    )
                },
            constants: try Self.record(ExpressionReader.self, in: container, forKey: .const)
                .mapValues(\.expression),
            variables: try Self.record(VariableReader.self, in: container, forKey: .variables)
                .mapValues(\.variable),
            procedures: try Self.record(ProcedureReader.self, in: container, forKey: .procedures)
                .mapValues(\.procedure)
        )
    }

    // MARK: - Public
    // MARK: - Private
    // What the document says it takes from its link, read and not judged. What
    // it is held against is what the module sends, which is a fact about the
    // module rather than about the text, so the refusal is the module's.
    //
    // Nothing written is nothing claimed, and a slot written as null says the
    // same. Whether a document may leave it out at all is the door's, which
    // reads the claim off the draft this answers.
    private static func imports(
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Set<Name>? {
        guard container.contains(.imports), try !container.decodeNil(forKey: .imports) else { return nil }

        let written = try container.superDecoder(forKey: .imports)

        return Set(try written.read([String].self).map { spelled in try Name.read(spelled, at: written.steps) })
    }

    // One of the slots a module declares a record of things under, read
    // standing on the slot so that what is refused inside it is addressed
    // there. Nothing written is nothing declared, which is what an absent slot
    // is and what a slot written as null says.
    private static func record<T: Decodable>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> [Name: T] {
        guard container.contains(key), try !container.decodeNil(forKey: key) else { return [:] }

        let written = try container.superDecoder(forKey: key)

        return try written.read([Name: T].self)
    }

    // A document says which language it is written for, and one that does not
    // is not a document. Any version but this reader's is refused. Read
    // through its own container, before the keys are judged, so a reader too
    // old for a document says so rather than refusing its keys.
    private static func checkVersion(in decoder: Decoder) throws {
        let document = try decoder.container(keyedBy: AnyCodingKey.self)
        let key = AnyCodingKey(stringValue: Module.versionKey.spelling)

        // About the document and not about anything in it: what is missing is
        // the one thing that would have made this a document, and there is
        // nothing written here to stand on.
        guard document.contains(key), try !document.decodeNil(forKey: key) else {
            throw ReadingError(
                "this is not a warp document. It does not say"
                    + " which warp it is written for (`\(Module.versionKey)`)",
                at: decoder.steps
            )
        }

        // The rest is about the version that is written, so it is read standing on
        // it. Refusing from out here would put the answer at the document's
        // first character, which is a line the author has no reason to look at.
        let written = try document.superDecoder(forKey: key)
        let version = try written.read(Int.self)

        // One version, because a document is spelled one way: the way the
        // writer of this version writes it. An older document is written
        // again, and a later one is for a reader that knows it.
        guard version == Self.version else {
            throw ReadingError(
                "this document is written for warp \(version), and this reads warp \(Self.version)."
                    + " Write it again for \(Self.version)",
                at: written.steps
            )
        }
    }
}
