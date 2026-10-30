//
//  ProcedureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A procedure: its own keys, the signature's and its body.
struct ProcedureReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case access
        case body
    }

    // MARK: - Property
    let procedure: Procedure

    // MARK: - Initializer
    // The keys and the access are read out of line, so a level of procedures
    // nested to the bound spends little stack, a debug build's included.
    init(from decoder: Decoder) throws {
        try Self.gate(decoder)

        let body = try Self.body(in: decoder)
        let access = try Self.access(in: decoder)

        // A procedure has no name of its own. It is named by the key its module
        // declares it under.
        self.procedure = Procedure(
            access: access ?? .internal,
            signature: try SignatureFieldsReader(reading: decoder).signature,
            body: body
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func gate(_ decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            extra: SignatureFieldsReader.CodingKeys.allCases.map(\.stringValue),
            context: "procedure"
        )
    }

    // The statements under `body`, none where it is not written.
    private static func body(in decoder: Decoder) throws -> Body {
        try decoder.descendingIfPresent(to: CodingKeys.body)?
            .read(BodyReader.self)
            .body ?? []
    }

    // One of three words, and a fourth is a document no reader can hold to
    // a scope. Absent, the declaration is the link's.
    private static func access(in decoder: Decoder) throws -> Access? {
        guard let written = try decoder.descendingIfPresent(to: CodingKeys.access) else { return nil }

        let spelling = try written.read(String.self)

        guard let access = Access(rawValue: spelling) else {
            throw ReadingError(
                "access '\(spelling)' is none of "
                    + Access.allCases.map { access in "`\(access.rawValue)`" }.joined(separator: ", "),
                at: written.steps
            )
        }

        return access
    }
}
