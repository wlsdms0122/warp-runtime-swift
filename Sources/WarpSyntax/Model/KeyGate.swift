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

        guard let first = unknown.first else { return }

        // Standing on the key that is turned away, which is where the refusal
        // is about. A reader shown the thing holding the keys has to find the
        // offending one themselves, and this refusal knows which it is. The
        // first by name, since the sentence names the rest.
        let written = try container.superDecoder(forKey: AnyCodingKey(stringValue: first))

        throw ReadingError(
            "\(context): unknown key(s)"
                + " \(unknown.joined(separator: ", "))"
                + " — known keys: \(known.sorted().joined(separator: ", "))",
            at: written.steps
        )
    }

    // MARK: - Private
}
