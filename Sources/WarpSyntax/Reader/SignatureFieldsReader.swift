//
//  SignatureFieldsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/10/26.
//

import Foundation
import Warp

// What a signature is written as beside the keys a procedure and a
// contract's procedure each write of their own: `parameters`, `returns`,
// `failing`, `const`, `isolated`, `bounds` and `sameTypes`. Each one left out
// says the least: no parameters, an answer of `Null`, no failure, and neither
// claim.
//
// A type parameter is bounded where its slots first name it, the parameters
// in order and then the answer, `some N: Standard.Numeric`, the way a head
// bounds one.
struct SignatureFieldsReader {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case returns
        case failing
        case const
        case isolated
        case bounds
        case sameTypes
    }

    // MARK: - Property
    let signature: Signature

    // MARK: - Initializer
    // Read beside other keys the caller has already held the mapping to.
    init(reading decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let parameters = try container.decodeIfPresent([ParameterReader].self, forKey: .parameters) ?? []
        let returns = try container.decodeIfPresent(TypeReader.self, forKey: .returns)?.bounded
        let bounds = try decoder.descendingIfPresent(to: CodingKeys.bounds)
        let labeled = try BoundsReader().bounds(
            try bounds?.read([Name: String].self),
            in: decoder.notation,
            at: bounds?.steps ?? decoder.steps
        )

        self.signature = Signature(
            parameters: parameters.map(\.parameter),
            returns: returns?.type ?? .null,
            failing: try container.decodeIfPresent(FailingReader.self, forKey: .failing)?.failing ?? .these([]),
            constness: try container.decodeIfPresent(Bool.self, forKey: .const) == true ? .const : .unstated,
            isolation: try container.decodeIfPresent(Bool.self, forKey: .isolated) == true ? .isolated : .unstated,
            bounds: try Self.bounds(of: parameters.flatMap(\.namings) + (returns?.namings ?? []))
                .merging(labeled) { introduced, _ in introduced },
            sameTypes: try decoder.descendingIfPresent(to: CodingKeys.sameTypes)?
                .read([Name: TypeReader].self).mapValues { same in try same.unbounded() } ?? [:]
        )
    }

    // MARK: - Public
    // MARK: - Private
    // The bound written beside each type parameter's first naming. One
    // written at a later naming is refused where it stands.
    private static func bounds(of namings: [TypeReader.Naming]) throws -> [Name: Set<Name>] {
        let (bounds, again) = TypeReader.introduced(namings)

        if let again {
            throw ReadingError(
                "bounds '\(again.name)' where it is named again. A signature bounds a type parameter where"
                    + " its slots first name it",
                at: again.steps
            )
        }

        return bounds
    }
}
