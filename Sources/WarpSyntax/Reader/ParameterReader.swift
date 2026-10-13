//
//  ParameterReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A parameter, written as a mapping under the name its body reads it by. A
// notation may offer the pair form, `count: Int`; a document has the one
// spelling.
struct ParameterReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case name
    }

    // MARK: - Property
    let parameter: Parameter

    // The type parameters its type names, where a bound may stand beside the
    // first.
    let namings: [TypeReader.Naming]

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        let notation = decoder.notation

        // The pair form: one key that is the name, holding the type or the
        // rest of the mapping. One key is always the pair where a notation
        // offers it, `name` included, since the mapping holding nothing but a
        // name reads either way and the notation picks this one.
        if
            notation.pairedParameter,
            let keyed = try? decoder.container(keyedBy: AnyCodingKey.self),
            keyed.allKeys.count == 1,
            let key = keyed.allKeys.first
        {
            let name = try Name.read(key.stringValue, at: decoder.steps)

            if let spelled = try? keyed.decode(String.self, forKey: key) {
                do {
                    let type = try TypeReader.reading(spelled, in: notation, at: decoder.steps).bounded

                    self.parameter = Parameter(name: name, type: type.type)
                    self.namings = type.namings
                } catch let error as TypeFormError {
                    throw ReadingError(error.message, at: decoder.steps)
                }

                return
            }

            let rest = try keyed.decode(ParameterFieldsReader.self, forKey: key)

            self.parameter = Parameter(
                name: name,
                type: rest.type,
                description: rest.description
            )
            self.namings = rest.namings

            return
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            extra: ParameterFieldsReader.CodingKeys.allCases.map(\.stringValue),
            context: "parameter"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try Name.read(try container.decode(String.self, forKey: .name), at: decoder.steps)
        let fields = try ParameterFieldsReader(reading: decoder)

        self.parameter = Parameter(name: name, type: fields.type, description: fields.description)
        self.namings = fields.namings
    }

    // MARK: - Public
    // MARK: - Private
}
