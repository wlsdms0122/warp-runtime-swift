//
//  ParameterReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A parameter, written as a record under the name its body reads it by. A
// notation may offer the pair form, `count: int`; a document has the one
// spelling.
public struct ParameterReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case name
        case type
        case candidates = "enum"
        case description
    }

    // MARK: - Property
    public let parameter: Parameter

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let notation = decoder.userInfo[.notation] as? Notation ?? .canonical

        // The pair form: one key that is the name, holding the type or the
        // rest of the record. A record with `name` in it is the document's
        // own form whatever else it holds, so the two never meet.
        if
            notation.pairedParameter,
            let keyed = try? decoder.container(keyedBy: AnyCodingKey.self),
            keyed.allKeys.count == 1,
            let key = keyed.allKeys.first,
            key.stringValue != CodingKeys.name.stringValue
        {
            let name = try Name.read(key.stringValue, at: decoder.steps)

            if let spelled = try? keyed.decode(String.self, forKey: key) {
                do {
                    self.parameter = Parameter(
                        name: name,
                        type: try TypeReader.parse(spelled) { name in notation.qualified(name, as: .type) }
                    )
                } catch let error as TypeFormError {
                    throw ReadingError(error.message, at: decoder.steps)
                }

                return
            }

            let rest = try keyed.decode(ParameterFieldsReader.self, forKey: key)

            self.parameter = Parameter(
                name: name,
                type: rest.type,
                candidates: rest.candidates,
                description: rest.description
            )

            return
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "input param"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rest = try ParameterFieldsReader(from: decoder)

        self.parameter = Parameter(
            name: try Name.read(try container.decode(String.self, forKey: .name), at: decoder.steps),
            type: rest.type,
            candidates: rest.candidates,
            description: rest.description
        )
    }

    // MARK: - Public
    // MARK: - Private
}
