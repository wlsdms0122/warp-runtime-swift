//
//  Fanout.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

// Running closures at once. An isolated closure is a body that is safe to run
// beside another (it writes no name it captured, touches no module variable and
// cannot leave past its own edge) so "run these concurrently" is a thing a procedure
// can be handed, and the grammar does not need a construct to say it. Which
// closures are isolated the link derived, and each piece is asked as it is
// started.
//
// One machine under three procedures, because what a piece is, how it is started and
// how a failure is reported are the same for all three, and only what "done"
// means differs.
//
// The rest a sibling ignores: asking is what cancellation is. A piece that
// carries on still finishes, and its answer is discarded.
struct Fanout: Sendable {
    // What one piece answered. A struct rather than a tuple, which the task
    // group needs for its child results.
    private struct Outcome: Sendable {
        let key: Name?
        let position: Int
        let value: Value?
        let failure: (any Error)?

        var label: Name { key ?? Name(normal: "[\(position)]") }
    }

    // One closure to run: its name if its author gave one, where it sat, and
    // what it is offered. How a piece is reported is `Outcome`'s to derive.
    private struct Piece: Sendable {
        let key: Name?
        let position: Int
        let closure: Closure
        let arguments: [(name: Name, value: Value)]
    }

    // MARK: - Property
    // The declared spelling, because `first` and `map` are also collection
    // procedures. A refusal that says which module's procedure refused is the one a
    // caller can act on.
    private let name: String

    // MARK: - Initializer
    init(_ name: String) {
        self.name = name
    }

    // MARK: - Public
    // Every piece, waited for. A failure fails the whole procedure, and every
    // piece's failure is reported, keyed by the piece's label: which failures
    // there are is not allowed to depend on timing.
    func all<P: NativeProcedure>(_ invocation: Invocation<P>) async throws -> Value {
        let (pieces, keyed) = try closures(of: invocation)
        let outcomes = await outcomes(of: pieces, via: invocation, racing: false)

        let failures = failures(among: outcomes)

        guard failures.isEmpty else { throw failure(among: failures) }

        return try answered(outcomes, keyed: keyed)
    }

    // The first success, with the rest asked to stop. Which piece wins is the
    // one fact here that timing decides, and the procedure's name says so.
    func first<P: NativeProcedure>(_ invocation: Invocation<P>) async throws -> Value {
        // The keys of a record are not wasted on a `first`. The winner's is
        // not reported, but a failure's is: when nothing wins, every piece's
        // failure comes back keyed by the name its author gave it.
        let (pieces, _) = try closures(of: invocation)

        // A `first` with nothing in it has nothing to win it, and waiting for
        // no one answers nothing. Refused as the author mistake it is. `all`
        // and `map` answer collections, and a collection may be empty; a
        // `first` answers exactly one thing, so it cannot be.
        guard !pieces.isEmpty else {
            throw ExecutionError("\(name) asks at least one closure, and none arrived")
        }

        let outcomes = await outcomes(of: pieces, via: invocation, racing: true)

        guard let winner = outcomes.first(where: { outcome in outcome.value != nil })?.value else {
            throw failure(among: failures(among: outcomes))
        }

        return winner
    }

    // One closure run once per element, answered in the collection's order.
    func map<P: NativeProcedure>(
        _ invocation: Invocation<P>,
        over material: Value,
        by handed: Value
    ) async throws -> Value {
        let pieces = try mapped(over: material, by: handed)
        let outcomes = await outcomes(of: pieces, via: invocation, racing: false)

        let failures = failures(among: outcomes)

        guard failures.isEmpty else { throw failure(among: failures) }

        return try answered(outcomes, keyed: false)
    }

    // MARK: - Private
    // One piece per name, in the order the names stand.
    private func pieces(of held: Value.Dictionary) throws -> [Piece] {
        try held.entries.enumerated().map { position, entry in
            Piece(
                key: entry.name,
                position: position,
                closure: try closure(entry.value, called: entry.name.spelling),
                arguments: []
            )
        }
    }

    // The receiver. Closures to run, under names for named pieces or an array
    // for positional ones. Which one arrived decides the shape of the answer.
    private func closures<P: NativeProcedure>(
        of invocation: Invocation<P>
    ) throws -> ([Piece], keyed: Bool) {
        switch invocation.receiver ?? .null {
        case let .record(record):
            return (try pieces(of: record.asDictionary), keyed: true)

        case let .dictionary(held):
            return (try pieces(of: held), keyed: true)

        case let .array(elements):
            return (
                try elements.enumerated().map { position, element in
                    Piece(
                        key: nil,
                        position: position,
                        closure: try closure(element, called: "[\(position)]"),
                        arguments: []
                    )
                },
                keyed: false
            )

        case let value:
            throw ExecutionError(
                "\(name) asks a record or an array of closures, and was sent \(value.type)"
            )
        }
    }

    // The pieces of `map`: the collection sets how many, the one closure is
    // every piece's body. Each call is offered the element and where it sat,
    // and the closure's own signature says which of those it reads.
    private func mapped(over material: Value, by handed: Value) throws -> [Piece] {
        // Through the one projection that owns the bytes equation, so a fan-out
        // walks bytes the way `each` does. Read straight from the projection
        // rather than out of a copy of it. A fan-out makes a piece for every
        // element by definition, so what this saves is the one intermediate
        // array and not the making of the elements.
        guard let elements = material.elements else {
            throw ExecutionError("\(name) walks an array, and was sent \(material.type)")
        }

        guard case let .procedure(by) = handed else {
            // Unset and set-to-something-else are different mistakes, and the
            // message says which one was made.
            guard handed != .null else {
                throw ExecutionError("\(name) asks a closure under 'by', and none arrived")
            }

            throw ExecutionError("\(name) asks a closure under 'by', and was sent \(handed.type)")
        }

        return elements.enumerated().map { position, element in
            Piece(
                key: nil,
                position: position,
                closure: by,
                arguments: [(name: "item", value: element), (name: "index", value: .int(position))]
            )
        }
    }

    private func closure(_ value: Value, called label: String) throws -> Closure {
        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "\(name) runs closures, and piece \(label) is \(value.type)"
            )
        }

        // The slot asks for isolated closures, so a piece that reached here
        // has already been settled against that. Asked again at the procedure's own
        // door, where a host that assembled the invocation itself arrives.
        guard closure.runsBeside else {
            throw ExecutionError(
                "\(name) runs isolated closures, and piece \(label) writes"
                    + " what another body could touch"
            )
        }

        return closure
    }

    private func outcomes<P: NativeProcedure>(
        of pieces: [Piece],
        via invocation: Invocation<P>,
        racing: Bool
    ) async -> [Outcome] {
        await withTaskGroup(of: Outcome.self) { group in
            for piece in pieces {
                group.addTask { await outcome(of: piece, via: invocation) }
            }

            var collected: [Outcome] = []

            for await outcome in group {
                collected.append(outcome)

                // A `first` stops at the first success. The rest are asked to
                // stop rather than made to. A piece that ignores the ask still
                // finishes, and its answer is discarded. Returning without the
                // ask would still await every sibling.
                if racing, outcome.value != nil {
                    group.cancelAll()

                    break
                }
            }

            return collected
        }
    }

    private func outcome<P: NativeProcedure>(
        of piece: Piece,
        via invocation: Invocation<P>
    ) async -> Outcome {
        do {
            return Outcome(
                key: piece.key,
                position: piece.position,
                value: try await answer(piece, via: invocation),
                failure: nil
            )
        } catch {
            return Outcome(key: piece.key, position: piece.position, value: nil, failure: error)
        }
    }

    // What a piece answers, through the environment's isolation boundary.
    // Ambient state a caller carries on the task must not reach every piece at
    // once.
    private func answer<P: NativeProcedure>(
        _ piece: Piece,
        via invocation: Invocation<P>
    ) async throws -> Value {
        // The frame carries the bare name. Rendering is what brackets it.
        let frame = piece.key?.spelling ?? "\(piece.position)"

        guard let environment = invocation.environment else {
            return try await invocation.call(
                piece.closure,
                offering: piece.arguments,
                piece: frame
            )
        }

        return try await environment.isolateConcurrentWork {
            try await invocation.call(
                piece.closure,
                offering: piece.arguments,
                piece: frame
            )
        }
    }

    private func failures(among outcomes: [Outcome]) -> [Name: any Error] {
        outcomes.reduce(into: [:]) { failures, outcome in
            if let failure = outcome.failure {
                failures[outcome.label] = failure
            }
        }
    }

    // Deterministic by piece label. A dictionary walk must not decide which
    // author mistake gets reported.
    private func failure(among failures: [Name: any Error]) -> any Error {
        let ordered = failures.sorted { left, right in left.key < right.key }

        if let authorMistake = ordered.first(where: { _, error in
            !(error is any RecoverableFailure)
        }) {
            return authorMistake.value
        }

        return ConcurrentFailed(failures: failures.mapValues { error in "\(error)" })
    }

    private func answered(_ outcomes: [Outcome], keyed: Bool) throws -> Value {
        guard keyed else {
            return .array(
                outcomes
                    .sorted { left, right in left.position < right.position }
                    .compactMap(\.value)
            )
        }

        // Through the door every value born outside a link comes through: the
        // keys are the author's, and two pieces under one key is the author's
        // mistake to hear about.
        return .dictionary(
            try Value.Dictionary(
                outcomes
                    .sorted { left, right in left.position < right.position }
                    .compactMap { outcome in
                        guard let key = outcome.key, let value = outcome.value else { return nil }

                        return (name: key, value: value)
                    }
            )
        )
    }
}
