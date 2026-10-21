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
        case description
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
            description: try Self.description(in: decoder),
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
            extra: SignatureFieldsReader.CodingKeys.allCases.map(\.stringValue)
                + [decoder.notation.answerKey?.spelling].compactMap { key in key },
            context: "procedure"
        )
    }

    // The statements under `body`, and where the notation offers an answer
    // key, the `return` it is read as after them.
    private static func body(in decoder: Decoder) throws -> Body {
        var body = try decoder.descendingIfPresent(to: CodingKeys.body)?
            .read(BodyReader.self)
            .body ?? []

        guard
            let key = decoder.notation.answerKey.map({ key in AnyCodingKey(stringValue: key.spelling) }),
            try decoder.container(keyedBy: AnyCodingKey.self).contains(key)
        else {
            return body
        }

        let answer = try decoder.descendingIfPresent(to: key)?.read(ExpressionReader.self).expression

        body.append(Statement(expression: .leave(.procedure(answer))))

        return body
    }

    private static func description(in decoder: Decoder) throws -> String? {
        try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(String.self, forKey: .description)
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
