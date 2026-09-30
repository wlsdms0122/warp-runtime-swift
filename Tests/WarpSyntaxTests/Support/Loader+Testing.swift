//
//  Loader+Testing.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

extension Loader {
    static let testing = Loader(
        registry: try! ConstructRegistry.standard.registering(FailForm.self)
    )

    // Reading a document without saying which document it is. These tests are
    // about what a reader accepts, not about pointing a refusal back into the
    // file it came from, so there is nothing here to name.
    func load(_ value: Value) throws -> Module {
        try load(value, identity: nil)
    }

    // A document as a front end hands one over: written in this notation's
    // spellings, lowered, and only then read. The two calls are the two
    // questions (what a text spells, and whether its program holds) and the
    // reading is handed a document with no spellings left in it.
    //
    // The version is filled in, which nobody writes by hand. A fixture that
    // sends procedures still writes its own `imports`: what a program takes from
    // its link is the author's to say, and a helper that said it for them
    // would make every fixture's list true by construction.
    //
    // Tests about the envelope itself call `load` directly, because for those
    // the envelope is the subject rather than the ceremony.
    func loadDocument(_ value: Value, from notation: Notation = .testing) throws -> Module {
        guard case let .dictionary(document) = value else { return try load(value, identity: nil) }

        var written = document

        if written[Envelope.versionKey] == nil {
            written = written.writing(Envelope.versionKey, with: .int(Envelope.version))
        }

        if written[Envelope.importsKey] == nil {
            written = written.writing(Envelope.importsKey, with: .array([]))
        }

        // The entry is named outside the text, so the text is not where its
        // word is written.
        return try load(try canonical(.dictionary(written), from: notation), identity: nil).publishing(entryName)
    }

    // Most tests here are about one construct or one reader, not about the
    // envelope a module is written in, so they write a procedure's body and this
    // names it. What the envelope itself accepts is `ModuleNotationTests`.
    //
    // The fixture is a `Value` because that is what a loader takes. Writing
    // YAML here would import a front end, and then a parser bug could fail a
    // reader's test. The imports are supposed to say which layer a test is
    // about.
    func loadProcedure(
        _ value: Value,
        named name: Name = entryName,
        importing imports: [Name] = [],
        from notation: Notation = .testing
    ) throws -> Module {
        try loadDocument(
            [
                "imports": .array(imports.map { name in .string(name.spelling) }),
                "procedures": [name: value]
            ],
            from: notation
        )
    }
}
