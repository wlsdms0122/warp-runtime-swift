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
        let key: Value
        let position: Int
        let value: Value?
        let failure: (any Error)?

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // One closure to run: its key, the map's key it stood under or its
    // position in a list, and where it sat.
    private struct Piece: Sendable {
        // MARK: - Property
        let key: Value
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
    // piece's failure is reported, under the piece's key: which failures
    // there are is not allowed to depend on timing.
    func all<P: NativeProcedure>(
        _ invocation: Invocation<P>
    ) async throws -> Value where P.Parameters == FanoutOperand {
        let (pieces, keyed) = try closures(of: invocation)
        let outcomes = await outcomes(of: pieces, via: invocation, racing: false)

        let failures = failures(among: outcomes)

        guard failures.isEmpty else { throw failure(among: failures) }

        return answered(outcomes, keyed: keyed)
    }

    // The first success, with the rest asked to stop. Which piece wins is the
    // one fact here that timing decides, and the procedure's name says so.
    func first<P: NativeProcedure>(
        _ invocation: Invocation<P>
    ) async throws -> Value where P.Parameters == FanoutOperand {
        // The keys of a map are not wasted on a `first`. The winner's is
        // not reported, but a failure's is: when nothing wins, every piece's
        // failure comes back under the key its author gave it.
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
    // What the fan-out was handed. Closures to run, under keys in a map or
    // at positions in an array, a position being a list piece's key. Which
    // one arrived decides the type of the answer.
    private func closures<P: NativeProcedure>(
        of invocation: Invocation<P>
    ) throws -> ([Piece], keyed: Bool) where P.Parameters == FanoutOperand {
        switch invocation[.pieces] {
        // One piece per entry, in the key order the map holds them in.
        case let .dictionary(held):
            return (
                try held.entries.enumerated().map { position, entry in
                    Piece(
                        key: entry.key,
                        position: position,
                        closure: try closure(entry.value)
                    )
                },
                keyed: true
            )

        case let .array(elements):
            return (
                try elements.enumerated().map { position, element in
                    Piece(
                        key: .int(position),
                        position: position,
                        closure: try closure(element)
                    )
                },
                keyed: false
            )

        default:
            throw ExecutionError("\(name) asks an Array or a Dictionary of closures")
        }
    }

    private func closure(_ value: Value) throws -> Closure {
        guard case let .procedure(closure) = value else {
            throw ExecutionError("\(name) asks every piece to be a closure")
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
    // Ambient state a host carries on the task must not reach every piece at
    // once.
    private func answer<P: NativeProcedure>(
        _ piece: Piece,
        via invocation: Invocation<P>
    ) async throws -> Value {
        // The frame carries the key as `text` spells it, and the trace
        // brackets it.
        let frame = Rendering(piece.key).text()

        guard let environment = invocation.environment as? ConcurrentEnvironment else {
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

    // In the pieces' order, which for a map is its key order: a walk of
    // the failures must not decide which author mistake gets reported.
    private func failures(among outcomes: [Outcome]) -> [Outcome] {
        outcomes
            .filter { outcome in outcome.failure != nil }
            .sorted { left, right in left.position < right.position }
    }

    private func failure(among failures: [Outcome]) -> any Error {
        if let authorMistake = failures.first(where: { outcome in
            !(outcome.failure is any RecoverableFailure)
        })?.failure {
            return authorMistake
        }

        return ConcurrentFailed(
            failures: failures.reduce(into: Value.Dictionary([:])) { gathered, outcome in
                if let payload = (outcome.failure as? any RecoverableFailure)?.payload {
                    gathered = gathered.writing(key: outcome.key, with: payload)
                }
            }
        )
    }

    // A list's answers in its order, a map's under the keys it held.
    private func answered(_ outcomes: [Outcome], keyed: Bool) -> Value {
        let ordered = outcomes.sorted { left, right in left.position < right.position }

        guard keyed else { return .array(ordered.compactMap(\.value)) }

        return .dictionary(
            ordered.reduce(into: Value.Dictionary([:])) { answers, outcome in
                if let value = outcome.value {
                    answers = answers.writing(key: outcome.key, with: value)
                }
            }
        )
    }
}
