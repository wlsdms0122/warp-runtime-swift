//
//  ReadingError.swift
//  WarpSyntax
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Warp

// What a document is refused with while it is being read.
//
// Reading a document is decoding, and decoding refuses with `DecodingError`:
// a sentence and the address the reader had reached, and nothing about which
// document either belongs to. A caller holding several documents needs the
// third fact to act on the first two — one of four files it just read is the
// one to open, and a refusal that does not say which sends it opening all of
// them.
//
// So the coding path becomes the steps of a place, which is the same address
// spelled the way every other stage spells one, and the document is the one the
// door was told it was reading.
public struct ReadingError: WarpError {
    // MARK: - Property
    public let message: String
    public let place: Place?

    // MARK: - Initializer
    public init(_ message: String, at place: Place?) {
        self.message = message
        self.place = place
    }

    // A decoding refusal, said about a document. Which key it stopped at is
    // already in hand — `keyNotFound` holds the key the path does not, since
    // the reader never got as far as descending into it.
    init(_ error: DecodingError, in document: Place.Document) {
        let (said, path): (String, [any CodingKey]) = switch error {
        case let .dataCorrupted(context):
            (context.debugDescription, context.codingPath)

        case let .keyNotFound(key, context):
            (context.debugDescription, context.codingPath + [key])

        case let .typeMismatch(_, context):
            (context.debugDescription, context.codingPath)

        case let .valueNotFound(_, context):
            (context.debugDescription, context.codingPath)

        @unknown default:
            ("\(error)", [])
        }

        self.message = said
        self.place = Place(
            path.map { key in key.intValue.map(Place.Step.index) ?? .key(key.stringValue) },
            in: document
        )
    }

    // MARK: - Public
    // MARK: - Private
}
