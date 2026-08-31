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
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case warp
        case needs
        case name
        case description
        case types
        case constraints
        case const
        case procedures
    }

    // MARK: - Property
    public let module: Module

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // The version first, and through its own container, because everything
        // after it is read by rules a newer document may not be written to —
        // including which keys exist. A later version adding a key would
        // otherwise be turned away as malformed, and a reader has to tell "I am
        // too old for this" (upgrade me) from "this is wrong" (fix the sender).
        try Self.check(
            version: try decoder
                .container(keyedBy: AnyCodingKey.self)
                .decodeIfPresent(Int.self, forKey: AnyCodingKey(stringValue: Envelope.versionKey)),
            at: decoder.steps
        )

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "module"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        let procedures = try container.decode([String: ProcedureReader].self, forKey: .procedures)

        guard !procedures.isEmpty else {
            throw ReadingError(
                "a module that declares nothing can never be"
                    + " linked into anything — write at least one procedure",
                at: decoder.steps
            )
        }

        let module = Module(
            name: try container.decodeIfPresent(String.self, forKey: .name),
            description: try container.decodeIfPresent(String.self, forKey: .description),
            types: try container
                .decodeIfPresent([String: TypeReader].self, forKey: .types)?
                .mapValues(\.type) ?? [:],
            constraints: try container
                .decodeIfPresent([String: [TypeReader]].self, forKey: .constraints)?
                .mapValues { members in members.map(\.type) } ?? [:],
            constants: try container
                .decodeIfPresent([String: ExpressionReader].self, forKey: .const)?
                .mapValues(\.expression) ?? [:],
            procedures: procedures.mapValues(\.procedure)
        )

        // A document that lists what it needs is held to the list. A caller
        // reads it to decide whether to run the program at all, so a list that
        // was allowed to drift would be worse than none — it would be trusted
        // and wrong.
        if let claimed = try container.decodeIfPresent([String].self, forKey: .needs) {
            let sent = Envelope.needs(of: module)

            guard Set(claimed) == sent else {
                throw ReadingError(
                    "this document says it needs"
                        + " \(claimed.sorted()) and sends \(sent.sorted())",
                    at: decoder.steps
                )
            }
        }

        self.module = module
    }

    // MARK: - Public
    // MARK: - Internal
    // What the document calls itself, without reading the document.
    //
    // A refusal from the reading says which document it is about, and the
    // reading is the thing that failed — so the one key that answer needs is
    // read here, where a module's keys are, rather than spelled a second time
    // wherever the refusal is assembled.
    //
    // It answers where `init(from:)` refuses. They are two questions: whether
    // this document may be read at all, and what to call the document a
    // refusal is about. So a `name` that is not text is nothing to call it by,
    // and the refusal for writing one is the reading's — this one going first
    // would answer every refusal about the name key by refusing again.
    //
    // A name written empty is no name, which is what a place already says
    // about an empty statement name: the two ways of writing nothing spell the
    // same, and only one of them can be the one this answers with.
    static func namespace(of value: Value) -> String? {
        guard case let .object(fields) = value,
            case let .string(name)? = fields[CodingKeys.name.stringValue],
            !name.isEmpty
        else { return nil }

        return name
    }

    // MARK: - Private
    // A document says which language it is written for, and one that does not is
    // not a document. Reading silence as the earliest would mean guessing at the
    // one question that has to be answerable from the bytes alone — and it is
    // what lets a file of some other shape entirely walk in and be turned away
    // for its keys rather than for what it is.
    //
    // Anything outside the range this reader knows is refused rather than guessed
    // at — below it, the document is claiming a language that never existed.
    private static func check(version: Int?, at steps: [Place.Step]) throws {
        guard let version else {
            throw ReadingError(
                "this is not a warp document — it does not say"
                    + " which warp it is written for (`\(Envelope.versionKey)`)",
                at: steps
            )
        }

        guard (Envelope.earliest ... Envelope.version).contains(version) else {
            throw ReadingError(
                "this document is written for warp \(version),"
                    + " and this reads \(Envelope.earliest) through \(Envelope.version)",
                at: steps
            )
        }
    }
}
