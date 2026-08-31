//
//  KeyGate.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

public struct KeyGate {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func rejectUnknownKeys<K: CodingKey & CaseIterable>(
        in decoder: Decoder,
        known: K.Type,
        extra: [String] = [],
        context: String
    ) throws {
        try rejectUnknownKeys(
            in: decoder,
            known: K.allCases.map(\.stringValue) + extra,
            context: context
        )
    }

    public func rejectUnknownKeys(
        in decoder: Decoder,
        known: [String],
        context: String
    ) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let unknown = container.allKeys
            .map(\.stringValue)
            .filter { key in !known.contains(key) }
            .sorted()

        // The address is one of the keys and not the thing holding them. A
        // reader shown where the object starts has to find the offending key
        // themselves, and this is the one refusal that already knows which key
        // it is. The first by name, since the sentence names the rest.
        guard let first = unknown.first else { return }

        throw ReadingError(
            "\(context): unknown key(s)"
                + " \(unknown.joined(separator: ", "))"
                + " — known keys: \(known.sorted().joined(separator: ", "))",
            at: decoder.steps + [.key(first)]
        )
    }

    // MARK: - Private
}
