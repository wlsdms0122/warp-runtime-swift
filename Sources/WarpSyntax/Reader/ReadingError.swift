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
// It carries the two halves of a place apart: the steps, known where the
// refusal happens, and the document, known where the reading began. Until
// that says, there is no document and the place is nothing.
//
// A place only becomes more exact: `read(in:)` keeps the first document it
// was told, and `asked(at:)` keeps the deeper of two addresses.
public struct ReadingError: WarpError {
    // MARK: - Property
    public let message: String

    // Where the reading had reached, in the document's own terms.
    public let steps: [Place.Step]

    private let document: Place.Document?

    public var place: Place? {
        document.map { document in Place(steps, in: document) }
    }

    // MARK: - Initializer
    init(_ message: String, at steps: [Place.Step] = []) {
        self.message = message
        self.steps = steps
        self.document = nil
    }

    private init(_ message: String, at steps: [Place.Step], in document: Place.Document?) {
        self.message = message
        self.steps = steps
        self.document = document
    }

    // A decoding refusal, with the address the walk knows.
    //
    // `DecodingError` has an address of its own and it is not this one: a
    // coding key carries whatever number its spelling parses to, so the walk's
    // own steps are taken instead and the sentence is all that is read off the
    // refusal. What the reader wrote is right; where it says it is is not its
    // to say.
    init(_ error: DecodingError, at steps: [Place.Step]) {
        let said = switch error {
        case let .dataCorrupted(context): context.debugDescription
        case let .keyNotFound(_, context): context.debugDescription
        case let .typeMismatch(_, context): context.debugDescription
        case let .valueNotFound(_, context): context.debugDescription
        @unknown default: "\(error)"
        }

        self.init(said, at: steps, in: nil)
    }

    // MARK: - Public
    // The same refusal, told which document it was reading. Said once, where
    // the reading began: a refusal already told keeps what it was told, so a
    // reading inside another cannot rename its document.
    func read(in document: Place.Document) -> ReadingError {
        guard self.document == nil else { return self }

        return ReadingError(message, at: steps, in: document)
    }

    // The same refusal, addressed from where it was asked for. For what refuses
    // somewhere with no address to give. A refusal that has one keeps it: where
    // it happened is deeper than where it was asked for, and the deeper place
    // is the true one.
    func asked(at steps: [Place.Step]) -> ReadingError {
        self.steps.isEmpty ? ReadingError(message, at: steps, in: document) : self
    }

    // MARK: - Private
}
