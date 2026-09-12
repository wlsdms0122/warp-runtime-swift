//
//  ModuleReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A document, which is a module and not a procedure: metadata, and the procedures
// it declares.
//
// There is no top level to run. A body written at the root would make every
// document an entry point and leave no way to write one that only declares.
// Procedures are named here and which one runs is said at link time, so a
// document that declares three of them is ordinary rather than a special case.
public struct ModuleReader: Decodable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case warp
        case imports
        case description
        case types
        case constraints
        case contracts
        case satisfies
        case const
        case variables = "var"
        case procedures
    }

    // MARK: - Property
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
            context: "module"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Read standing on the procedures rather than on the module holding
        // them, because what is refused just below is about the procedures. A
        // reading is addressed where it is, so being where the answer is is
        // the whole of what puts an author on the right line.
        let written = try container.superDecoder(forKey: .procedures)
        let procedures = try written.read([String: ProcedureReader].self).named(at: written.steps)

        guard !procedures.isEmpty else {
            throw ReadingError(
                "a module that declares nothing can never be"
                    + " linked into anything. Write at least one procedure",
                at: written.steps
            )
        }

        self.draft = Draft(
            description: try container.decodeIfPresent(String.self, forKey: .description),
            imports: try Self.imports(in: container),
            types: try Self.record(TypeReader.self, in: container, forKey: .types)
                .mapValues(\.type),
            constraints: try Self.record([TypeReader].self, in: container, forKey: .constraints)
                .mapValues { members in members.map(\.type) },
            contracts: try Self.record(
                [String: ContractProcedureReader].self,
                in: container,
                forKey: .contracts
            )
                .mapValues { procedures in try procedures.mapValues(\.signature).named(at: []) },
            claims: try Self.record([String].self, in: container, forKey: .satisfies)
                .mapValues { contracts in try Set(contracts).named(at: []) },
            constants: try Self.record(ExpressionReader.self, in: container, forKey: .const)
                .mapValues(\.expression),
            variables: try Self.record(ExpressionReader.self, in: container, forKey: .variables)
                .mapValues(\.expression),
            procedures: procedures.mapValues(\.procedure)
        )
    }

    // MARK: - Public
    // MARK: - Internal
    // MARK: - Private
    // What the document says it takes from its link, read and not judged. What
    // it is held against is what the module sends, which is a fact about the
    // module rather than about the text, so the refusal is the module's.
    //
    // Nothing written is nothing claimed, and a slot written as null says the
    // same. Whether a document may leave it out at all is the door's, and the
    // door sees the value rather than a container.
    private static func imports(
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Set<Name>? {
        guard try Envelope.declaresImports(in: container, forKey: .imports) else { return nil }

        let written = try container.superDecoder(forKey: .imports)

        return try Set(written.read([String].self)).named(at: written.steps)
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

        return try written.read([String: T].self).named(at: written.steps)
    }

    // A document says which language it is written for, and one that does not
    // is not a document. Reading silence as the earliest would mean guessing at
    // the one question that has to be answerable from the bytes alone, and it
    // is what lets a file of some other kind entirely walk in and be turned
    // away for its keys rather than for what it is.
    //
    // Anything outside the range this reader knows is refused rather than
    // guessed at. Below it, the document is claiming a language that never
    // existed. Read through its own container, before anything else and before
    // the keys are judged, because everything after it is read by rules a newer
    // document may not be written to. Including which keys exist. A later
    // version adding a key would otherwise be turned away as malformed, and a
    // reader has to tell "I am too old for this" (upgrade me) from "this is
    // wrong" (fix the sender).
    private static func checkVersion(in decoder: Decoder) throws {
        let envelope = try decoder.container(keyedBy: AnyCodingKey.self)
        let key = AnyCodingKey(stringValue: Envelope.versionKey.spelling)

        // About the document and not about anything in it: what is missing is
        // the one thing that would have made this a document, and there is
        // nothing written here to stand on.
        guard envelope.contains(key), try !envelope.decodeNil(forKey: key) else {
            throw ReadingError(
                "this is not a warp document. It does not say"
                    + " which warp it is written for (`\(Envelope.versionKey)`)",
                at: decoder.steps
            )
        }

        // The rest is about the procedure that is written, so it is read standing on
        // it. Refusing from out here would put the answer at the document's
        // first character, which is a line the author has no reason to look at.
        let written = try envelope.superDecoder(forKey: key)
        let version = try written.read(Int.self)

        guard (Envelope.earliest ... Envelope.version).contains(version) else {
            throw ReadingError(
                "this document is written for warp \(version),"
                    + " and this reads \(Envelope.earliest) through \(Envelope.version)",
                at: written.steps
            )
        }
    }
}
