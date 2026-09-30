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
// closures are isolated the link derived, and the slot holds every piece to it
// before this runs.
//
// One machine under two procedures, because what a piece is, how it is started
// and how a failure is reported are the same for both, and only what "done"
// means differs.
//
// The rest a sibling ignores: asking is what cancellation is. A piece that
// carries on still finishes, and its answer is discarded.
struct Fanout: Sendable {
    // What one piece answered. A struct rather than a tuple, which the task
    // group needs for its child results.
    private struct Outcome: Sendable {
        // MARK: - Property
        let key: Name?
        let position: Int
        let value: Value?
        let failure: (any Error)?

        var label: Name { key ?? Name(normal: "[\(position)]") }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // One closure to run: its name if its author gave one, and where it sat.
    // How a piece is reported is `Outcome`'s to derive.
    private struct Piece: Sendable {
        // MARK: - Property
        let key: Name?
        let position: Int
        let closure: Closure

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The declared spelling, because `first` is also a collection procedure. A
    // refusal that says which module's procedure refused is the one a caller
    // can act on.
    private let name: String

    // MARK: - Initializer
    init(_ name: String) {
        self.name = name
    }

    // MARK: - Public
    // Every piece, waited for. A failure fails the whole procedure, and every
    // piece's failure is reported, keyed by the piece's label: which failures
    // there are is not allowed to depend on timing.
    func all<P: NativeProcedure>(
        _ invocation: Invocation<P>
    ) async throws -> Value where P.Parameters == FanoutOperand {
        let (pieces, keyed) = try closures(of: invocation)
        let outcomes = await outcomes(of: pieces, via: invocation, racing: false)

        let failures = failures(among: outcomes)

        guard failures.isEmpty else { throw failure(among: failures) }

        return try answered(outcomes, keyed: keyed)
    }

    // The first success, with the rest asked to stop. Which piece wins is the
    // one fact here that timing decides, and the procedure's name says so.
    func first<P: NativeProcedure>(
        _ invocation: Invocation<P>
    ) async throws -> Value where P.Parameters == FanoutOperand {
        // The keys of a record are not wasted on a `first`. The winner's is
        // not reported, but a failure's is: when nothing wins, every piece's
        // failure comes back keyed by the name its author gave it.
        let (pieces, _) = try closures(of: invocation)

        // A `first` with nothing in it has nothing to win it, and waiting for
        // no one answers nothing. Refused as the author mistake it is. `all`
        // answers a collection, and a collection may be empty; a `first`
        // answers exactly one thing, so it cannot be.
        guard !pieces.isEmpty else {
            throw ExecutionError("\(name) asks at least one closure, and none arrived")
        }

        let outcomes = await outcomes(of: pieces, via: invocation, racing: true)

        guard let winner = outcomes.first(where: { outcome in outcome.value != nil })?.value else {
            throw failure(among: failures(among: outcomes))
        }

        return winner
    }

    // MARK: - Private
    // One piece per name, in the order the names stand.
    private func pieces(of held: Value.Dictionary) throws -> [Piece] {
        try held.entries.enumerated().map { position, entry in
            Piece(
                key: entry.name,
                position: position,
                closure: try closure(entry.value)
            )
        }
    }

    // What the fan-out was handed. Closures to run, under names for named
    // pieces or an array for positional ones. Which one arrived decides the
    // type of the answer.
    private func closures<P: NativeProcedure>(
        of invocation: Invocation<P>
    ) throws -> ([Piece], keyed: Bool) where P.Parameters == FanoutOperand {
        switch invocation[.pieces] {
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
                        closure: try closure(element)
                    )
                },
                keyed: false
            )

        default:
            throw ExecutionError("\(name) asks a record or an array of closures")
        }
    }

    private func closure(_ value: Value) throws -> Closure {
        guard case let .procedure(closure) = value else {
            throw ExecutionError("\(name) runs closures")
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
                handing: [],
                piece: frame
            )
        }

        return try await environment.isolateConcurrentWork {
            try await invocation.call(
                piece.closure,
                handing: [],
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

        return ConcurrentFailed(
            failures: failures.compactMapValues { error in (error as? any RecoverableFailure)?.payload }
        )
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
