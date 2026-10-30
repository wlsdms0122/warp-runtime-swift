//
//  Loader+Testing.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

extension Loader {
    // A document with the version filled in, which nobody writes by hand, and
    // `imports` written empty where the fixture writes none. A fixture that
    // sends procedures writes its own `imports`: what a program takes from its
    // link is the author's to say, and a helper that said it for them would
    // make every fixture's list true by construction.
    //
    // Tests about the envelope itself call `load` directly, because for those
    // the envelope is the subject rather than the ceremony.
    func loadDocument(_ value: Value) throws -> Module {
        guard case let .dictionary(document) = value else { return try load(value) }

        var written = document

        if written[Module.versionKey] == nil {
            written = written.writing(Module.versionKey, with: .int(ModuleReader.version))
        }

        if written[ModuleReader.CodingKeys.imports.name] == nil {
            written = written.writing(ModuleReader.CodingKeys.imports.name, with: .array([]))
        }

        // The entry is named outside the text, so the text is not where its
        // word is written.
        return try load(.dictionary(written)).publishing(entryName)
    }

    // Most tests here are about one construct or one reader, not about the
    // envelope a module is written in, so they write a procedure's body and this
    // names it. What the envelope itself accepts is `DocumentEnvelopeTests`.
    func loadProcedure(
        _ value: Value,
        named name: Name = entryName,
        importing imports: [Name] = []
    ) throws -> Module {
        try loadDocument(
            [
                "imports": .array(imports.sorted().map { name in .string(name.spelling) }),
                "procedures": [name: value]
            ]
        )
    }
}
