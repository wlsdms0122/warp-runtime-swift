//
//  CompiledStatement.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// One statement compiled: the code it runs, where it stands, and where its
// value lands. The value lands once the statement has ended, so a write that
// refuses is refused in the list holding the statement and not in the
// statement.
struct CompiledStatement: Sendable {
    enum Landing: Sendable {
        case bind(Int)

        // A new box, so a variable declared inside a nested body shadows
        // rather than writes an outer one of the same name.
        case declare(Int, Name)

        // A write lands in a box the enclosing bodies also hold.
        case assign(Address)

        // A write lands in the slot, which holds the variable unboxed.
        case store(Address)

        // A nameless statement ran, and its value is dropped, which is what
        // leaving the name off said.
        case drop

        // A `return` standing last in a body: a statement that leaves, so it
        // is watched starting and failing but never completing, and what it
        // carries is the statement's value.
        case answer

        var completes: Bool {
            guard case .answer = self else { return true }

            return false
        }
    }

    // MARK: - Property
    let code: CompiledCode
    let site: Site
    let landing: Landing

    // MARK: - Initializer
    init(_ code: CompiledCode, at site: Site, landing: Landing) {
        self.code = code
        self.site = site
        self.landing = landing
    }

    // MARK: - Public
    // What the statement gives the list holding it: null, but for an answer,
    // which gives what it carries.
    @inline(__always)
    nonisolated(nonsending) func run(_ activation: inout Activation, _ evaluator: Evaluator) async throws -> Value {
        let result = try await watched(in: &activation, by: evaluator)

        switch landing {
        case let .bind(slot):
            activation.cells[slot] = .value(result)

        case let .declare(slot, name):
            activation.cells[slot] = .hold(Handle(name, result))

        case let .assign(address):
            guard case let .hold(handle) = activation.cells[address.slot] else {
                throw RunRefused(
                    "'\(activation.spelled(address).rendered)' writes a name that is not a variable here"
                )
            }

            try handle.write(result, at: try activation.projections(of: address))

        case let .store(address):
            try activation.write(result, at: address)

        case .drop:
            break

        case .answer:
            return result
        }

        return .null
    }

    // MARK: - Private
    // The statement run where an observer may watch it. A refusal leaving the
    // statement takes the statement's place with it, unless it already
    // carries one: the innermost is where the mistake is, and every statement
    // it passes through on the way out is only where the run was. The trace
    // is built only where one is read: for an observer, and for a refusal
    // that carries none yet.
    @inline(__always)
    private nonisolated(nonsending) func watched(in activation: inout Activation, by evaluator: Evaluator) async throws -> Value {
        if let observer = evaluator.observer {
            return try await observed(by: observer, in: &activation, by: evaluator)
        }

        do {
            return try await code.run(&activation, evaluator)
        } catch let leaving as Leaving {
            throw leaving
        } catch {
            throw Self.refusal(error) { activation.trace(at: site) }
        }
    }

    private nonisolated(nonsending) func observed(
        by observer: any ExecutionObserver,
        in activation: inout Activation,
        by evaluator: Evaluator
    ) async throws -> Value {
        let inside = activation.trace(at: site)

        await observer.statementStarted(at: inside)

        do {
            let result = try await code.run(&activation, evaluator)

            // What a statement made is handed to the host, out of the run.
            if landing.completes {
                await observer.statementCompleted(at: inside, result: result.dropped)
            }

            return result
        } catch let leaving as Leaving {
            throw leaving
        } catch {
            let refused = Self.refusal(error) { inside }

            await observer.statementFailed(at: inside, error: refused)

            throw refused
        }
    }

    private static func refusal(_ error: any Error, at trace: () -> Trace) -> any Error {
        guard let refused = error as? any WarpError, refused.trace == nil else { return error }

        return refused.tracing(trace())
    }
}
