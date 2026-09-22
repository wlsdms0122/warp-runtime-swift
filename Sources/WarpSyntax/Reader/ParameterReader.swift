//
//  ParameterReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A parameter, written as a record. A notation may offer a bare type where a
// parameter is wanted; a document has the one spelling.
public struct ParameterReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case candidates = "enum"
        case `default`
        case description
    }

    // MARK: - Property
    public let parameter: Parameter

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // The shorthand: a bare type where a parameter is wanted, where the
        // notation offers it. Anything a type can be spelled as works there,
        // so `array<string>` is as short as `string` is.
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            let notation = decoder.userInfo[.notation] as? Notation ?? .canonical

            guard notation.bareParameter else {
                throw ReadingError(
                    "a parameter is written as a record, { type: \(single) } at the least",
                    at: decoder.steps
                )
            }

            do {
                self.parameter = Parameter(type: try TypeReader.parse(single, qualifying: notation.qualified))
            } catch let error as TypeFormError {
                throw ReadingError(
                    error.message,
                    at: decoder.steps
                )
            }

            return
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "input param"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Omitting `type:` declares nothing, which is not the same as declaring
        // `any`. Both take whatever arrives; only one of them says so.
        let type = try container.decodeIfPresent(TypeReader.self, forKey: .type)?.type

        // The default is stored as written. Whether the parameter itself admits
        // it is a declaration fact judged at the link (the one place a default
        // written against a declared type name could be judged at all) and a
        // default-supplied slot reads the declared representation because
        // taking one settles it, the same gate a caller's value walks.
        self.parameter = Parameter(
            type: type,
            candidates: try container.decodeIfPresent([String].self, forKey: .candidates),
            default: container.contains(.default)
                ? try container.decode(ValueReader.self, forKey: .default).value
                : nil,
            description: try container.decodeIfPresent(String.self, forKey: .description)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
