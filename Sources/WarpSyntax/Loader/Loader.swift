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
// Reading takes a document, which has no spellings, so nothing here holds a
// notation. Spending takes a notation's own text and the table it is written
// with, and answers with the document it spells.
//
// A front end with a document stops at `Value`. A YAML or JSON parser produces
// data; turning that data into a procedure is this one path, and what every
// notation shares is the `Expression` it arrives at rather than the spellings used
// to get there. A front end with a syntax of its own builds those expressions
// directly and never comes through here.
public struct Loader: Sendable {
    // MARK: - Property
    public let registry: ConstructRegistry

    // MARK: - Initializer
    public init(registry: ConstructRegistry = .standard) {
        self.registry = registry
    }

    // MARK: - Public
    // Every procedure a notation reaches on its own through this table. From the
    // readers that spell one, and from the forms registered here. A document
    // written entirely in these spellings still needs them declared somewhere
    // in its link, so a host assembling a graph can ask what it owes before
    // assembling it.
    //
    // What a notation says with a procedure rather than a construct is its own
    // to state.
    public func vocabulary(of notation: Notation) -> Set<Name> {
        registry.vocabulary(with: notation).union(notation.vocabulary)
    }

    // A document read into a module: the load, which every document comes
    // through.
    // It reads a document and nothing else: a spelling a notation offers has
    // been spent by the time a document exists. What runs is decided when the
    // module is linked with the others.
    //
    // Which document this is is handed in, and stated rather than defaulted,
    // since a module is checked where it is made and a refusal names the
    // document it came from. A caller with no document says `nil`.
    //
    //     let module = try Loader().load(document, identity: Identity.of(document))
    public func load(_ value: Value, identity: Identity?) throws -> Module {
        // Which document every refusal from here is about, worked out before
        // anything is read: what fails is the reading, and a reader that got
        // far enough to fail may not have got far enough to say what it was
        // reading.
        let document = Place.Document(identity: identity)

        // Reading first and checking second, and both before the imports
        // question below.
        let draft = try reading(by: .standard) { try spelled(value, in: document, by: .standard) }
        let module = try reading(by: .standard) { try Module(draft, identity: identity) }

        // A document says what it imports, which a host reads to decide what
        // to grant before it links. Whether the list is right is the
        // Validator's. Asked after the reading, so a document that does not
        // read is refused for that first.
        guard draft.imports != nil else {
            throw ReadingError(
                "a document says what it imports, and this one does not."
                    + " Write `\(ModuleReader.CodingKeys.imports.name)`, empty where the program uses nothing"
            )
            .read(in: document)
        }

        // A document says each thing one way: what the writer writes for the
        // program it read. Anything else is a second text for one program, and
        // a second identity for it.
        //
        // A document is read and written by the standard table, the one
        // `canonical` writes with. A table a host composes is for what it
        // spends into a document, and a document is spelled one way.
        let spelling = try Writer(registry: .standard, readBy: .canonical).value(of: module)

        if let (steps, held) = value.divergence(from: spelling) {
            throw ReadingError(
                "a document says each thing one way, and this says it another way here."
                    + " The one way writes \(try held.map(TextEncoding().line(from:)) ?? "nothing")",
                at: steps
            )
            .read(in: document)
        }

        return module
    }

    // The document a text is: what it spells in a notation, written back out
    // the one way a document is written, with the version and, where the text
    // claimed none, the imports filled in. Nothing here is judged: a program
    // with a name nothing declares is still that document. The imports are
    // filled here because the procedures a text sends are what its notation's
    // spellings were spent into, which its author never wrote; a text that
    // claimed a list keeps it, and is held to it on the way in. A version the
    // value already carries is left as it is, for the reading to refuse where
    // it is not this reader's.
    public func canonical(_ value: Value, from notation: Notation) throws -> Value {
        let stamped = try stamped(value)

        // Written for the reader every document has: the standard table and
        // no notation. What this loader's own table reads as a construct is
        // spent here, and what reads the document back reads it by the
        // standard table.
        return try Writer(registry: .standard, readBy: .canonical)
            .value(of: try spelled(stamped, in: Place.Document(identity: nil), from: notation))
    }

    // One procedure, read from a procedure's worth of data rather than a
    // document. A fragment is in no document, so a refusal from here names
    // none, and its steps lead to what was wrong inside what was handed in.
    // Which notation it is written in is the caller's to say; what it is held
    // to is the module's it is declared in.
    public func procedure(from value: Value, in notation: Notation = .canonical) throws -> Procedure {
        try read(ProcedureReader.self, from: value, in: .assembled, from: notation).procedure
    }

    // A body read on its own, for a caller assembling a procedure rather than a
    // document. A fragment is no module, so what comes back reaches a link
    // inside one.
    public func body(from value: Value, in notation: Notation = .canonical) throws -> Body {
        try read(BodyReader.self, from: value, in: .assembled, from: notation).body
    }

    public func statement(from value: Value, in notation: Notation = .canonical) throws -> Statement {
        try read(StatementReader.self, from: value, in: .assembled, from: notation).statement
    }

    public func expression(from value: Value, in notation: Notation = .canonical) throws -> Warp.Expression {
        try read(ExpressionReader.self, from: value, in: .assembled, from: notation).expression
    }

    // Whatever this does, with anything it refuses addressed in the spellings the
    // document uses.
    //
    // The language names its own slots, which is the reading a caller that
    // assembled a program in Swift is owed: it wrote no document, so no
    // document's keys would lead it anywhere. A caller holding a text is owed
    // the other reading (`condition` is a slot they cannot look for and `while`
    // is what they typed) and this is where a stage that has no document of its
    // own gets it.
    //
    //     let image = try await loader.reading { try await Builder().build(modules) }
    //
    // `load` places its own refusals this way; a build's are placed here.
    public func reading<T>(_ refused: () throws -> T) throws -> T {
        try reading(by: registry, refused)
    }

    // The same, for a caller whose reading runs. A build folds constants, which
    // runs host procedures, so what it raises arrives here through a suspension.
    public func reading<T>(_ refused: () async throws -> T) async throws -> T {
        do {
            return try await refused()
        } catch let refusal as any WarpError {
            guard let place = refusal.place else { throw refusal }

            throw refusal.placed(place.written(by: registry))
        }
    }

    // MARK: - Private
    // The same, with the places written by the table the text was read by.
    private func reading<T>(by table: ConstructRegistry, _ refused: () throws -> T) throws -> T {
        do {
            return try refused()
        } catch let refusal as any WarpError {
            guard let place = refusal.place else { throw refusal }

            throw refusal.placed(place.written(by: table))
        }
    }

    // What a document spells, unjudged: nothing here is held to the language's
    // rules, which `load` holds.
    private func spelled(
        _ value: Value,
        in document: Place.Document,
        from notation: Notation = .canonical,
        by table: ConstructRegistry? = nil
    ) throws -> Draft {
        try read(ModuleReader.self, from: value, in: document, from: notation, by: table).draft
    }

    // The value with this reader's version on it, where it does not say. What a
    // caller hands in is not yet a document and the version is the reason why:
    // it says which reader the document is written for, and that is an answer
    // about the writing rather than about the program.
    private func stamped(_ value: Value) throws -> Value {
        let document = try Self.document(value)

        guard document[Module.versionKey] == nil else { return value }

        return .dictionary(document.writing(Module.versionKey, with: .int(ModuleReader.version)))
    }

    // What a document holds, or the refusal saying this was not one.
    private static func document(_ value: Value) throws -> Value.Dictionary {
        // A value under a type's name is a value of that type. A document is
        // the reader's own data and stands under no name.
        if case let .record(record) = value, let settled = record.name {
            throw ReadingError("a document stands under no name, and this one stands under '\(settled)'")
        }

        guard let held = value.asDictionary else {
            throw ReadingError("a document is names and values, and this one is \(value.nominal)")
        }

        return held
    }

    // Every reading goes through here, and so does every refusal one raises.
    // Decoding says what is wrong and where in the data it stopped; which
    // document it is about is the caller's, handed in as `document`.
    private func read<T: Decodable>(
        _ type: T.Type,
        from value: Value,
        in document: Place.Document,
        from notation: Notation = .canonical,
        by table: ConstructRegistry? = nil
    ) throws -> T {
        // Held here rather than in each reader below: a value a caller built
        // reaches every reader through here, and past the bound the readers
        // recurse in the ordinary way.
        guard value.nesting <= Value.nestingBound else {
            throw ReadingError("nesting deeper than \(Value.nestingBound) containers", at: value.deepest).read(in: document)
        }

        let userInfo: [CodingUserInfoKey: Any] = [
            .constructRegistry: table ?? registry,
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
        // A reader written outside this package may refuse in `Codable`'s
        // terms, and `ValueDecoder` turns that into a reading at the boundary
        // it crossed, which is the only place that still knows how deep it
        // was. So only a reading arrives here.
    }
}
