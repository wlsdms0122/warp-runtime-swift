//
//  Probe.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/22/26.
//

import Foundation
import Warp

// What a program case got when it was asked, and for a `builds` case the
// object it builds.
struct Probe {
    // Refused at a stage, answered (straight, and through its objects), or
    // neither because the asking threw.
    enum Outcome {
        case refused(Refusal)
        case answered(Value, roundTrip: Result<Value, any Error>)
        case threw(any Error)
    }

    // MARK: - Property
    let outcome: Outcome
    let built: Result<Value, any Error>?

    // MARK: - Initializer
    init(asking program: Case.Program, through runner: Runner) async {
        self.outcome = await Self.outcome(of: program, through: runner)
        self.built = if case .builds = program.expectation {
            await Self.result { try await runner.built(program) }
        } else {
            nil
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func outcome(of program: Case.Program, through runner: Runner) async -> Outcome {
        do {
            if let refusal = try await runner.reached(program) { return .refused(refusal) }

            let answered = try await runner.run(program)

            return .answered(answered, roundTrip: await result { try await runner.roundTrip(program) })
        } catch {
            return .threw(error)
        }
    }

    private static func result<Success>(_ body: () async throws -> Success) async -> Result<Success, any Error> {
        do {
            return .success(try await body())
        } catch {
            return .failure(error)
        }
    }
}
