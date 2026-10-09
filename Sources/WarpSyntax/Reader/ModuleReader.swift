//
//  ModuleReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A document, which is a module and not a procedure: metadata, and the procedures
// it declares. Which procedure runs is named when a run starts.
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
    // procedure. A procedure is vocabulary, and vocabulary is what `imports` is for.
    //
    // Every document says it. A reader that filled in a default would be
    // reading a document that never said which language it was written for, and
    // a file that is not a document at all would get as far as having its keys
    // judged. Turned away for being a malformed module rather than for not
    // being one.
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

        let procedures = try container.superDecoder(forKey: .procedures).read([Name: ProcedureReader].self)

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
                    // spells it; the contracts it claims are names to read.
                    let type = entry.key
                    let steps: [Place.Step] = [.key(CodingKeys.satisfies.rawValue), .key(entry.key.spelling)]

                    // Two contracts that read as one are one contract claimed
                    // twice, however the text spelled them.
                    let contracts = try entry.value.map { spelled in notation.qualified(try Name.read(spelled, at: steps), as: .type) }

                    guard Set(contracts).count == contracts.count else {
                        throw ReadingError("'\(type)' claims a contract twice under satisfies", at: steps)
                    }

                    claims[type] = Set(contracts)
                },
            constants: try Self.record(ExpressionReader.self, in: container, forKey: .const)
                .mapValues(\.expression),
            variables: try Self.record(VariableReader.self, in: container, forKey: .variables)
                .mapValues(\.variable),
            procedures: procedures.mapValues(\.procedure)
        )
    }

    // MARK: - Public
    // Whether a document declares what it imports.
    //
    // Written and not null. A key holding nothing is not a claim, and the two
    // who ask have to agree about that: the door turns away a document that
    // declares nothing, and the reader takes a key holding nothing as a list
    // of no names. Answering differently is how `imports: Null` passes the
    // door as a claim while the module behind it says it takes nothing.
    //
    // Asked twice because the two are in different places. The door holds the
    // document and reads the value; the reader is inside it and has a
    // container. One rule, said here for both.
    static func declaresImports(_ written: Value?) -> Bool {
        guard let written else { return false }

        return written != .null
    }

    static func declaresImports<Key: CodingKey>(
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Bool {
        try container.contains(key) && !container.decodeNil(forKey: key)
    }

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
        guard try Self.declaresImports(in: container, forKey: .imports) else { return nil }

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
    // is not a document. Reading silence as some version would mean guessing
    // at the one question that has to be answerable from the bytes alone, and
    // it is what lets a file of some other kind entirely walk in and be turned
    // away for its keys rather than for what it is.
    //
    // Any version but this reader's is refused rather than guessed at. Read
    // through its own container, before anything else and before
    // the keys are judged, because everything after it is read by rules a newer
    // document may not be written to. Including which keys exist. A later
    // version adding a key would otherwise be turned away as malformed, and a
    // reader has to tell "I am too old for this" (upgrade me) from "this is
    // wrong" (fix the sender).
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
