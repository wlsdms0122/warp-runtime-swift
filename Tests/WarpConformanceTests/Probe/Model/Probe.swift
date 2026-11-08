//
//  Probe.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/22/26.
//

import Foundation
import Warp

// What a program case got when it was asked.
struct Probe {
    // Refused at a stage, returned (straight, and through its objects), or
    // neither because the asking threw. A `builds` case starts no run and
    // gets the object it builds.
    enum Outcome {
        case refused(Refusal)
        case returned(Value, roundTrip: Result<Value, any Error>)
        case threw(any Error)
        case built(Result<Value, any Error>)
    }

    // MARK: - Property
    let outcome: Outcome

    // MARK: - Initializer
    init(asking program: Case.Program, through runner: Runner) async {
        self.outcome = if case .builds = program.expectation {
            .built(await Self.result { try await runner.built(program) })
        } else {
            await Self.outcome(of: program, through: runner)
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func outcome(of program: Case.Program, through runner: Runner) async -> Outcome {
        do {
            if let refusal = try await runner.reached(program) { return .refused(refusal) }

            let returned = try await runner.run(program)

            return .returned(returned, roundTrip: await result { try await runner.roundTrip(program) })
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
