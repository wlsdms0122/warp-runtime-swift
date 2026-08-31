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
// It carries the two halves of a place separately, because they are known at
// different moments. The steps are known where the refusal happens — the walk
// is there, and only there — and which document is being read is known at the
// door the value came through. So the reading says where it got to, the door
// says what it was reading, and neither has to hold the other's answer to say
// its own.
//
// Until a door says, there is no document and the place is nothing rather than
// an empty one: a refusal that has not reached a door has not been told, and a
// reader guessing would be answering the one question it was never given.
public struct ReadingError: WarpError {
    // MARK: - Property
    public let message: String

    // Where the reading had reached, in the document's own words.
    public let steps: [Place.Step]

    private let document: Place.Document?

    public var place: Place? {
        document.map { document in Place(steps, in: document) }
    }

    // MARK: - Initializer
    public init(_ message: String, at steps: [Place.Step] = []) {
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
    // The same refusal, told which document it was reading. Said once, at the
    // door: a refusal already told keeps what it was told, so a door inside a
    // door cannot rename another's document.
    func read(in document: Place.Document) -> ReadingError {
        guard self.document == nil else { return self }

        return ReadingError(message, at: steps, in: document)
    }

    // The same refusal, addressed from where it was asked for — for what
    // refuses somewhere with no address to give. A refusal that has one keeps
    // it: where it happened is deeper than where it was asked for, and the
    // deeper answer is the true one.
    func asked(at steps: [Place.Step]) -> ReadingError {
        self.steps.isEmpty ? ReadingError(message, at: steps, in: document) : self
    }

    // The same refusal, with one step of its address said better. A walk
    // descends into an array knowing only that it is an array; the reader that
    // knows the array holds statements is the only one that can name them, and
    // everywhere else an element is a position and nothing more.
    //
    // Which element is asked of the caller rather than told to it: the refusal
    // knows where it happened and the reader knows what lives there, and this
    // is where the two meet.
    func naming(at depth: Int, _ name: (Int) -> String?) -> ReadingError {
        guard case let .index(position)? = steps[safe: depth] else { return self }

        var named = steps
        named[depth] = .statement(name(position), at: position)

        return ReadingError(message, at: named, in: document)
    }

    // MARK: - Private
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
