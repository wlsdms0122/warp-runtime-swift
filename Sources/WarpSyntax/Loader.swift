//
//  Loader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// Data in, IR out, and the two questions kept apart.
//
// Reading takes a document, which has no spellings — so nothing here holds a
// notation, and a reader that did would be a reader with a notation's opinions
// about a text that has none. Lowering takes a notation's own text and the
// table it is written with, and answers with the document it spells.
//
// A front end with a document stops at `Value`. A YAML or JSON parser produces
// data; turning that data into a procedure is this one path, and what every
// notation shares is the `Expression` it arrives at rather than the words used
// to get there. A front end with a syntax of its own builds those expressions
// directly and never comes through here, the way a compiler builds its back
// end's instructions rather than printing them and reading them back.
public struct Loader: Sendable {
    // MARK: - Property
    public let registry: ConstructRegistry

    // MARK: - Initializer
    public init(registry: ConstructRegistry = .standard) {
        self.registry = registry
    }

    // Every word a notation reaches on its own through this table — from the
    // readers that spell one, and from the forms registered here. A document
    // written entirely in these spellings still needs them declared somewhere
    // in its link, so a caller assembling a world can ask what it owes before
    // assembling it.
    //
    // What a notation says with a word rather than a construct is a choice it
    // made, so the debt is its own to state. Leaving it unstated would have the
    // bundles read as optional while the spellings quietly required them.
    public func vocabulary(of notation: Notation) -> Set<String> {
        registry.vocabulary(with: notation).union(notation.vocabulary)
    }

    // MARK: - Public
    // Loading is not decoding: decoding produces a fragment, and only this says
    // the fragment is a module worth linking. It reads a document and nothing
    // else — a spelling a notation offers has been spent by the time a document
    // exists, so there is no table here to read one with. It answers with a module rather
    // than something runnable because a document is not runnable — what runs is
    // decided when this module is linked with the others.
    //
    // Which document this is, handed in rather than worked out: deriving it
    // means writing the document back to its canonical bytes, and that is the
    // serialization's job — reading a document has never needed the wire.
    //
    //     let module = try Loader().load(document, identity: Identity.of(document))
    //
    // It goes in with what is being read rather than onto what came back. A
    // module is checked where it is made, so a stamp put on afterwards would
    // reach only the modules nothing was wrong with — and a refusal is exactly
    // the moment somebody wants the file it came from.
    //
    // Handing the wrong document to `Identity.of` is not a way to be pointed at
    // the wrong text: whatever compares identities computes its own side from
    // what it holds, so a mismatch is a refusal nobody can place, never a
    // refusal placed somewhere it did not come from.
    //
    // Stated and never defaulted. A caller with no document under what it is
    // handing in says `nil` out loud, and a caller that has one cannot forget
    // to say so — a module that came through here without being told which text
    // it came from would refuse without ever being able to say where, and
    // nothing would have gone wrong loudly enough to notice.
    public func load(_ value: Value, identity: Identity?) throws -> Module {
        // Which document every refusal from here is about, worked out before
        // anything is read: what fails is the reading, and a reader that got
        // far enough to fail may not have got far enough to say what it was
        // reading.
        let document = document(of: value, identity: identity)

        // Reading first and checking second, and both before the envelope
        // question below. A module is checked where it is made, so the stamp
        // goes in with what is being made rather than onto what came back — a
        // refusal is exactly the moment somebody wants the file it came from.
        let module = try reading { try Module(try spelled(value, in: document), identity: identity) }

        // What a document imports is read before the program it belongs to, so a
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
        guard case let .record(record) = value,
            Envelope.declaresImports(record[Envelope.importsKey])
        else {
            throw ReadingError(
                "a document says what it imports, and this one does not —"
                    + " write `\(Envelope.importsKey)`, empty where the program sends nothing"
            )
            .read(in: document)
        }

        return module
    }

    // The document a document is: what it spells, written back out the one way
    // a document is written, with the two things nobody writes by hand filled
    // in — the version, and the imports where the text claimed none.
    //
    // The notation is handed in rather than held, because it is an answer about
    // the text going in and not about the document coming out. What is spelled
    // one way here is spelled the one way afterwards, and the reading that
    // takes the result is a reading with no notation at all.
    //
    // What wants this is anything asking what a text *is* rather than whether
    // its program is any good — telling one document from another, which is
    // done on the canonical writing. A program with a name nothing declares is
    // still a document, and still that one, so nothing here is judged.
    //
    // It answers with a document and not with the module behind it: what is
    // being asked for is the text, and a module is the reading of one.
    //
    // Filling the imports is what makes this a front end's call and not a
    // reader's. A text in a notation has no author for that list — the words
    // it sends are what the spellings lowered to, which the author never
    // typed — so the side that lowered them is the side that can state them.
    // A text that claimed a list keeps it, and is held to it on the way in.
    //
    // So the way to make a document out of anything is this, and a caller that
    // then loads what it got is loading exactly what it will send.
    //
    // The version is put on before the reading rather than left to the writer
    // alone, because the reading refuses a value that does not say which warp
    // it is written for — so a caller left to stamp it first would be keeping
    // one half of this call's contract on this call's behalf, and two callers
    // will not keep it the same way. A number the value already carries is left
    // alone: a document claiming a language this reader is not is refused, and
    // that refusal is the version's whole job.
    public func canonical(_ value: Value, from notation: Notation) throws -> Value {
        // The value that is read and the value a refusal about it is named
        // after are one value, held once. Two calls to `stamped` would be two
        // values that happen to agree today about the one field this reads.
        let stamped = stamped(value)

        return try Writer(registry: registry, readBy: .canonical)
            .value(of: try spelled(stamped, in: document(of: stamped), from: notation))
    }

    // One procedure, for a caller holding a procedure's worth of data rather than a
    // document. A module is how a *file* declares procedures; a caller that has
    // exactly one and already knows what to call it does not have to write an
    // envelope around it to say so.
    //
    // A fragment is in no document — what it will be part of is the caller's,
    // and a refusal from here says so rather than naming a document it cannot
    // know. The steps still lead to what was wrong inside what was handed in.
    //
    // Which notation it is written in is the caller's to say, the same as it is
    // for a whole text. A caller holding a fragment of a document says nothing
    // and gets the document's reading.
    public func procedure(from value: Value, in notation: Notation = .canonical) throws -> Procedure {
        let procedure = try read(
            ProcedureReader.self,
            from: value,
            in: .assembled,
            from: notation
        )
        .procedure

        try reading { try Validator().validate(procedure) }

        return procedure
    }

    // Steps read on their own, for a caller assembling a body rather than a
    // document. Deliberately not `load`: a fragment is not a module and carries
    // no signature of its own, so what comes back still has to reach a link
    // inside something that does.
    public func statements(from value: Value, in notation: Notation = .canonical) throws -> [Statement] {
        try read(BodyReader.self, from: value, in: .assembled, from: notation).statements
    }

    public func statement(from value: Value, in notation: Notation = .canonical) throws -> Statement {
        try read(StatementReader.self, from: value, in: .assembled, from: notation).statement
    }

    public func expression(from value: Value, in notation: Notation = .canonical) throws -> Expression {
        try read(ExpressionReader.self, from: value, in: .assembled, from: notation).expression
    }

    // Whatever this does, with anything it refuses addressed in the words the
    // document uses.
    //
    // The language names its own slots, which is the reading a caller that
    // assembled a program in Swift is owed: it wrote no document, so no
    // document's words would lead it anywhere. A caller holding a text is owed
    // the other reading — `condition` is a slot they cannot look for and
    // `while` is what they typed — and this is where a stage that has no
    // document of its own gets it.
    //
    //     let image = try loader.reading { try Linker().link(modules, entry: "greet") }
    //
    // The reading path takes it on its own; a link is the stage that does not,
    // because what to link is the caller's statement and the modules in it may
    // have come from anywhere.
    public func reading<T>(_ refused: () throws -> T) throws -> T {
        do {
            return try refused()
        } catch let refusal as any WarpError {
            guard let place = refusal.place else { throw refusal }

            throw refusal.placed(place.written(by: registry))
        }
    }

    // MARK: - Private

    // What a document spells, unjudged. Not a door: nothing here has been held
    // to the language's rules, and `load` is the one that has.
    private func spelled(
        _ value: Value,
        in document: Place.Document,
        from notation: Notation = .canonical
    ) throws -> Draft {
        try read(ModuleReader.self, from: value, in: document, from: notation).draft
    }

    // The document a refusal about reading this value is in. The identity is
    // handed in where there is one and left out where there is not: what a
    // document *is* is worked out from its canonical writing, so a value on its
    // way to being written has none yet.
    private func document(of value: Value, identity: Identity? = nil) -> Place.Document {
        Place.Document(identity: identity)
    }

    // The value with this reader's version on it, where it does not say. What a
    // caller hands in is not yet a document and the version is the reason why:
    // it says which reader the document is written for, and that is an answer
    // about the writing rather than about the program.
    private func stamped(_ value: Value) -> Value {
        guard case let .record(record) = value, record[Envelope.versionKey] == nil else { return value }

        return .record(record.replacing(Envelope.versionKey, with: .int(Envelope.version)))
    }

    // Every reading goes through here, and so does every refusal one raises.
    // Decoding says what is wrong and where in the data it stopped, and knows
    // nothing about which document either is about — the door does, and it says
    // so by handing one in. A door that could read without saying would be a
    // refusal nobody can place, which is the state this asks about up front.
    private func read<T: Decodable>(
        _ type: T.Type,
        from value: Value,
        in document: Place.Document,
        from notation: Notation = .canonical
    ) throws -> T {
        let userInfo: [CodingUserInfoKey: Any] = [
            .constructRegistry: registry,
            .notation: notation
        ]

        do {
            return try ValueDecoder(
                value: value,
                codingPath: [],
                steps: [],
                userInfo: userInfo
            )
            .decode(type)
        } catch let refusal as ReadingError {
            throw refusal.read(in: document)
        }
        // Nothing arrives here refusing in `Codable`'s terms. A reader written
        // outside this package still refuses that way, and `ValueDecoder`
        // turns it into a reading at the boundary it crossed — which is the
        // only place that still knows how deep it was. Catching it again here
        // could only add a document to an address already thrown away.
    }
}

public extension CodingUserInfoKey {
    static let constructRegistry = CodingUserInfoKey(rawValue: "warp.constructRegistry")!
    static let notation = CodingUserInfoKey(rawValue: "warp.notation")!
}
