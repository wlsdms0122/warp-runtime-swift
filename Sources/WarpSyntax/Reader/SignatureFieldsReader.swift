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
// `bounds` and `sameTypes`. Absent `parameters` is an empty signature, not an
// absent one.
//
// A type parameter is bounded where its slots first name it, the parameters
// in order and then the answer, `some N: Standard.Numeric`, the way a head
// bounds one.
struct SignatureFieldsReader {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case returns
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
            returns: returns?.type,
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
        var named: Set<Name> = []
        var bounds: [Name: Set<Name>] = [:]

        for naming in namings {
            let first = named.insert(naming.name).inserted

            guard let bound = naming.bound else { continue }

            guard first else {
                throw ReadingError(
                    "bounds '\(naming.name)' where it is named again. A signature bounds a type parameter where"
                        + " its slots first name it",
                    at: naming.steps
                )
            }

            bounds[naming.name] = bound
        }

        return bounds
    }
}
