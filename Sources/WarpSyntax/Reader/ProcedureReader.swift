//
//  ProcedureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

public struct ProcedureReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case description
        case access
        case parameters
        case returns
        case bounds
        case body
        case result
    }

    // MARK: - Property
    public let procedure: Procedure

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "procedure"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        // A procedure's body and result are the same pair a block writes, so
        // they are joined by the same assembler and under the same rule.
        let block = try Block.reading(
            body: try decoder.descendingIfPresent(to: CodingKeys.body)?
                .read(BodyReader.self)
                .body ?? [],
            result: try decoder.descendingIfPresent(to: CodingKeys.result)?
                .read(ExpressionReader.self)
                .expression,
            at: decoder.steps
        )

        // One of three words, and a fourth is a document no reader can hold to
        // a scope. Absent, the declaration is the link's.
        let access = try container.decodeIfPresent(String.self, forKey: .access).map { spelling in
            guard let access = Access(rawValue: spelling) else {
                throw ReadingError(
                    "access '\(spelling)' is none of "
                        + Access.allCases.map { access in "`\(access.rawValue)`" }.joined(separator: ", "),
                    at: decoder.steps
                )
            }

            return access
        }

        // A procedure has no name of its own. It is named by the key its module
        // declares it under.
        self.procedure = Procedure(
            description: try container.decodeIfPresent(String.self, forKey: .description),
            access: access ?? .internal,
            // Absent `parameters:` means an empty signature, not an absent
            // contract. `parameters:`, `returns:` and `bounds:` are one
            // signature. What a call may pass, what comes back, and what each
            // type parameter admits.
            signature: try BoundsReader.apply(
                try container.decodeIfPresent([String: String].self, forKey: .bounds),
                qualifying: { name in (decoder.userInfo[.notation] as? Notation ?? .canonical).qualified(name, as: .type) },
                to: Signature(
                    parameters: try container
                        .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                        .signature.parameters ?? [],
                    returns: try container
                        .decodeIfPresent(TypeReader.self, forKey: .returns)?
                        .type
                ),
                at: decoder.steps
            ),
            // A procedure that only returns a value has nothing to do first, so
            // `body:` is what a procedure writes when it has statements rather
            // than something every procedure must write.
            body: block.body,
            // One expression, because a procedure answers one value. Several
            // named answers are one record, which is a thing an author writes
            // rather than a type this reader assembles. A document that
            // declares none answers with nothing, as a block does.
            result: block.result
        )
    }

    // MARK: - Public
    // MARK: - Private
}
