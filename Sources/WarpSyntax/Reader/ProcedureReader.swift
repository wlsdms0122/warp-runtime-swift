//
//  ProcedureReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

public struct ProcedureReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case description
        case parameters
        case receiver
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
            body: try container
                .decodeIfPresent(BodyReader.self, forKey: .body)?
                .statements ?? [],
            result: try container
                .decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression,
            at: decoder.steps
        )

        // A procedure has no name of its own — it is named by the key its module
        // declares it under.
        self.procedure = Procedure(
            description: try container.decodeIfPresent(String.self, forKey: .description),
            // Absent `parameters:` means an empty signature, not an absent
            // contract. `parameters:`, `receiver:`, `returns:` and `bounds:`
            // are one signature — what a call may pass, which of those it is
            // sent to, what comes back, and what each type parameter admits.
            signature: try BoundsReader.apply(
                try container.decodeIfPresent([String: String].self, forKey: .bounds),
                to: Signature(
                    receiver: try container.decodeIfPresent(String.self, forKey: .receiver),
                    parameters: try container
                        .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                        .signature.parameters ?? [:],
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
            // rather than a shape this reader assembles. A document that
            // declares none answers with nothing, as a block does.
            result: block.result
        )
    }

    // MARK: - Public
    // MARK: - Private
}
