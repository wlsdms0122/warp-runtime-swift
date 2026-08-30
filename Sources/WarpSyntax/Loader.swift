//
//  Loader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The door a notation comes through: data in, IR out. It holds the one thing a
// document needs and a procedure does not — the words its constructs are spelled
// with — together with the language it is judged against.
//
// A front end with a document stops at `Value`. A YAML or JSON parser produces
// data; turning that data into a procedure is this one path, and what every
// notation shares is the `Expression` it arrives at rather than the words used
// to get there. A front end with a syntax of its own builds those expressions
// directly and never comes through here, the way a compiler builds its back
// end's instructions rather than printing them and reading them back.
public struct Loader: Sendable {
    // MARK: - Property
    public let language: Language
    public let registry: ConstructRegistry
    public let notation: Notation

    // MARK: - Initializer
    public init(
        language: Language = Language(),
        registry: ConstructRegistry = .standard,
        notation: Notation = .canonical
    ) {
        self.language = language
        self.registry = registry
        self.notation = notation
    }

    // Every word this notation reaches on its own — from the readers that spell
    // one, and from the forms registered here. A document written entirely in
    // these spellings still needs them declared somewhere in its link, so a
    // caller assembling a world can ask what it owes before assembling it.
    //
    // What this notation says with a word rather than a construct is a choice it
    // made, so the debt is its own to state. Leaving it unstated would have the
    // bundles read as optional while the spellings quietly required them.
    public var vocabulary: Set<String> {
        registry.vocabulary(with: notation).union(notation.vocabulary)
    }

    // MARK: - Public
    // Loading is not decoding: decoding produces a fragment, and only this says
    // the fragment is a module worth linking. It answers with a module rather than
    // something runnable because a document is not runnable — what runs is
    // decided when this module is linked with the others.
    // The module carries no identity: working one out means writing the
    // document back to its canonical bytes, which is the serialization's job
    // and not this target's — reading a document has never needed the wire.
    // A caller that wants refusals it can map back into a file says so with
    // the document in hand:
    //
    //     let module = try Loader().load(document)
    //         .read(from: try Identity.of(document))
    //
    // Two lines and not one because the second is the wire's. Handing the
    // wrong document to the second line is not a way to be pointed at the
    // wrong text: what compares identities computes both sides from what it
    // holds, so a mismatch is a refusal nobody can place, never a refusal
    // placed somewhere it did not come from.
    public func load(_ value: Value) throws -> Module {
        let module = try spelled(value)

        // What a document needs is read before the program it belongs to, so a
        // caller decides whether to grant before it decides whether to link. A
        // document that leaves the list out is asking to be trusted about the
        // one thing that was worth checking, and silence is not a claim a
        // caller can act on — so the door a program arrives through wants it
        // said. Whether the list is *right* is the reader's, and it refuses
        // there.
        //
        // After the shapes and not before them: a document that will not even
        // read is refused for that. A missing list is the least specific thing
        // that can be wrong with a document, and going first would make it the
        // only thing an author ever heard about.
        guard case let .object(fields) = value, fields[Envelope.needsKey] != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "a document says what it needs, and this one"
                        + " does not — write `\(Envelope.needsKey)`, empty where the"
                        + " program sends nothing"
                )
            )
        }

        try language.validate(module)

        return module
    }

    // The module a document spells, unjudged.
    //
    // Reading and judging are two things and this is the first of them. What
    // wants it on its own is anything asking what a document *is* rather than
    // whether its program is any good — writing it back out canonically, which
    // is how a document is told from another document. A program with a name
    // nothing declares is still a document, and still that document.
    //
    // Not for running. Nothing here has been held to the language's rules, and
    // `load` is the door that has.
    public func spelled(_ value: Value) throws -> Module {
        try read(ModuleReader.self, from: value).module
    }

    // One procedure, for a caller holding a procedure's worth of data rather than a
    // document. A module is how a *file* declares procedures; a caller that has
    // exactly one and already knows what to call it does not have to write an
    // envelope around it to say so.
    public func procedure(from value: Value) throws -> Procedure {
        let procedure = try read(ProcedureReader.self, from: value).procedure

        try language.validate(procedure)

        return procedure
    }

    // Steps read on their own, for a caller assembling a body rather than a
    // document. Deliberately not `load`: a fragment is not a module and carries
    // no signature of its own, so what comes back still has to reach a link
    // inside something that does.
    public func statements(from value: Value) throws -> [Statement] {
        try read(BodyReader.self, from: value).statements
    }

    public func statement(from value: Value) throws -> Statement {
        try read(StatementReader.self, from: value).statement
    }

    public func expression(from value: Value) throws -> Expression {
        try read(ExpressionReader.self, from: value).expression
    }

    // MARK: - Private
    private func read<T: Decodable>(_ type: T.Type, from value: Value) throws -> T {
        try T(from: ValueDecoder(
            value: value,
            codingPath: [],
            userInfo: [
                .constructRegistry: registry,
                .notation: notation,
                .loader: self
            ]
        ))
    }
}

public extension CodingUserInfoKey {
    static let constructRegistry = CodingUserInfoKey(rawValue: "warp.constructRegistry")!
    static let loader = CodingUserInfoKey(rawValue: "warp.loader")!
    static let notation = CodingUserInfoKey(rawValue: "warp.notation")!
}
