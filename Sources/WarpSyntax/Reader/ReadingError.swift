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
// So the coding path becomes the steps of a place, and the document is the one
// the door was told it was reading.
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
    //
    // The document is walked beside the path because a coding key does not say
    // which kind of step it is. A dictionary key that reads as a number carries
    // an `intValue` — `procedures: { "12": … }` would address `procedures[12]`,
    // which is not a place in the document — and an array of statements is
    // spelled by the names its statements wrote everywhere else a place is
    // made. What the document holds at each step settles both.
    init(_ error: DecodingError, in document: Place.Document, reading value: Value) {
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
        self.place = Place(Self.steps(path, through: value), in: document)
    }

    // MARK: - Public
    // MARK: - Private
    private static func steps(_ path: [any CodingKey], through value: Value) -> [Place.Step] {
        var steps: [Place.Step] = []
        // What the document holds where the walk has reached, or nothing once
        // the path leads past what is written — a reader refusing a key the
        // document does not have walks one step further than the document goes.
        var reached: Value? = value

        for key in path {
            switch reached {
            case let .array(elements)?:
                guard let position = key.intValue, elements.indices.contains(position) else {
                    steps.append(Self.step(of: key))
                    reached = nil

                    continue
                }

                let element = elements[position]

                steps.append(
                    StatementReader.name(of: element)
                        .map { name in .statement(name: name, at: position) } ?? .index(position)
                )
                reached = element

            case let .object(fields)?:
                steps.append(.key(key.stringValue))
                reached = fields[key.stringValue]

            default:
                steps.append(Self.step(of: key))
                reached = nil
            }
        }

        return steps
    }

    // A step read from the key alone, for where the document ran out. Nothing
    // is left to tell a position from a name, so the key's own claim is all
    // there is.
    private static func step(of key: any CodingKey) -> Place.Step {
        key.intValue.map(Place.Step.index) ?? .key(key.stringValue)
    }
}
