//
//  BuildError.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// What the build refuses: a mistake in what an author wrote, such as a call
// that names nothing or hands what its callee never declared. No rescue holds
// one.
public struct BuildError: WarpError {
    // MARK: - Property
    public let message: String
    public let place: Place?

    // MARK: - Initializer
    // The place is stated and never defaulted, and what it says is where the
    // fix goes.
    //
    // Two modules declaring one name is two places, and the refusal is
    // addressed to the second (the declaration that cannot be added) with the
    // first named in the sentence. A build holds several documents and only the
    // host knows which file each arrived in, so a refusal that named neither
    // would send it opening all of them.
    //
    // A document and no steps is what is wrong with a document rather than with
    // anything in it: the same text handed over twice.
    public init(_ message: String, at place: Place) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> Self {
        BuildError(message, at: place)
    }

    // A body the build lowered without judging it first: what the lowering
    // cannot place is the build's own mistake rather than the author's, and
    // reads that way.
    static func unjudged(_ what: String, at place: Place) -> BuildError {
        BuildError("the build lowered \(what) without judging it", at: place)
    }

    // A spelling reached from outside the one document that may name it. Said
    // once, wherever a lookup fails on one.
    static func concealed(_ name: Name, at place: Place) -> BuildError {
        BuildError(
            "'\(name)' is private to the document that declares it, and nothing outside"
                + " that document names it",
            at: place
        )
    }

    // One name declared by two documents of a link, said once for a
    // procedure, a type and a contract, at the second declaration.
    static func declaredTwice(_ name: Name, by first: String, and second: String, at place: Place) -> BuildError {
        BuildError(
            "'\(name)' is declared by \(first) and by \(second)."
                + " Two declarations of a name have no way to be told apart",
            at: place
        )
    }

    // One name a link declares as a type and as a contract, which share a
    // namespace, at the declaration a document wrote second.
    static func declaredAsBoth(_ name: Name, type: String, contract: String, at place: Place) -> BuildError {
        BuildError(
            "'\(name)' is declared as both a type and a contract in this link, as a type by \(type) and as a"
                + " contract by \(contract). One name cannot stand for a type and a contract at once",
            at: place
        )
    }

    // MARK: - Private
}
