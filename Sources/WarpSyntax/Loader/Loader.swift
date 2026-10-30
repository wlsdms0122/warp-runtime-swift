//
//  Loader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A document in, a module out: the load every document comes through.
public struct Loader: Sendable {
    // MARK: - Property
    // The key an interface's tree holds the language version under, in the
    // place of a document's `warp`.
    static let interfaceKey: Name = "interface"

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // A document read into a module. What runs is decided when the module is
    // linked with the others.
    //
    // Which document this is is worked out from the document, so the module
    // and every refusal from its reading name the document it came from.
    //
    //     let module = try Loader().load(document)
    public func load(_ value: Value) throws -> Module {
        try load(value, identity: try Identity.of(value))
    }

    // An interface read into the module it declares, for a test to hold an
    // implementation to. Its tree is the one its text reads into, and past
    // the version under `interface` it is read and held to the one way as a
    // document is, each procedure with no body. An interface is no document,
    // so its module has no identity.
    package func interface(_ value: Value) throws -> Module {
        guard case let .dictionary(interface) = value, let version = interface[Self.interfaceKey] else {
            throw ReadingError("an interface says under `\(Self.interfaceKey)` the warp its declarations are written for")
        }

        return try load(
            .dictionary(interface.removing(Self.interfaceKey).writing(Module.versionKey, with: version)),
            identity: nil
        )
    }

    // MARK: - Private
    private func load(_ value: Value, identity: Identity?) throws -> Module {
        // Which document every refusal from here is about, worked out before
        // anything is read: what fails is the reading, and a reader that got
        // far enough to fail may not have got far enough to say what it was
        // reading.
        let document = Place.Document(identity: identity)

        // Reading first and checking second, and both before the imports
        // question below.
        let draft = try self.draft(of: value, in: document)
        let module = try Module(draft, identity: identity)

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
        let spelling = try Writer().value(of: module)

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

    // What a document writes, read and not yet judged: `load` holds it to the
    // language's rules. Every refusal the reading raises names `document`.
    private func draft(of value: Value, in document: Place.Document) throws -> Draft {
        // Held here rather than in each reader below: a value a caller built
        // reaches every reader through here, and past the bound the readers
        // recurse in the ordinary way.
        guard value.nesting <= Value.nestingBound else {
            throw ReadingError("nesting deeper than \(Value.nestingBound) containers", at: value.deepest).read(in: document)
        }

        // `ValueDecoder` turns a refusal in `Codable`'s terms into a reading
        // where it happened, so only a reading arrives here.
        do {
            return try ValueDecoder(value: value, codingPath: [], steps: [], userInfo: [:])
                .decode(ModuleReader.self)
                .draft
        } catch let refusal as ReadingError {
            throw refusal.read(in: document)
        }
    }
}
