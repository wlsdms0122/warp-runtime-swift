//
//  ConformanceTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
import Warp

// The specification's cases, asked through `Runner` and held to what each
// expects.
@Suite("The specification's cases")
struct ConformanceTests {
    // MARK: - Property
    private let runner = Runner()

    // MARK: - Initializer
    // MARK: - Test
    @Test("every case in the specification", arguments: try Case.all())
    func specificationCase(_ sut: Case) async throws {
        switch sut.asked {
        case let .program(program):
            switch program.expectation {
            case let .answers(expected):
                let returned = try await runner.run(program)

                #expect(returned.matchesStrictly(expected, text: .value), "\(sut.name): \(sut.note)")

            case let .refuses(stage):
                let reached = try await runner.reached(program)?.stage

                #expect(reached == stage, "\(sut.name): \(sut.note)")

            case let .builds(expected):
                let built = try await runner.built(program)

                #expect(built.matchesStrictly(expected, text: .scalars), "\(sut.name): \(sut.note)")
            }

        case let .object(object):
            switch object.expectation {
            case let .answers(expected):
                let returned = try await runner.run(object)

                #expect(returned.matchesStrictly(expected, text: .value), "\(sut.name): \(sut.note)")

            case let .refuses(stage):
                let reached = try await runner.reached(object)?.stage

                #expect(reached == stage, "\(sut.name): \(sut.note)")
            }

        case let .encoded(encoded, reading):
            switch reading {
            case let .reads(expected):
                #expect(try encoded.read().matchesStrictly(expected, text: .scalars), "\(sut.name): \(sut.note)")

            case let .spells(expected):
                #expect(try encoded.read().matchesStrictly(expected, text: .scalars), "\(sut.name): \(sut.note)")
                #expect(try encoded.written(expected) == encoded.data, "\(sut.name): \(sut.note)")

            case .refuses:
                #expect(throws: (any Error).self, "\(sut.name): \(sut.note)") { try encoded.read() }
            }
        }
    }

    @Test("the cases are the specification's, and it has some")
    func thereAreCases() throws {
        // Given. A suite that silently found nothing would pass, and passing by
        // asking nothing is the failure mode a conformance suite has
        let sut = try Case.all()

        #expect(sut.count >= 10)
        #expect(Set(sut.map(\.name)).count == sut.count)

        // A case is found by its name: a diff names the file and a failure names
        // the case, and a reader who has one goes looking for the other. Where
        // the two drift apart the case is still asked and still nobody finds it.
        let adrift = sut.filter { one in one.name != one.file }.map { one in "\(one.file) says '\(one.name)'" }

        #expect(adrift.isEmpty, "a case is named what its file is: \(adrift.joined(separator: ", "))")
    }

    // MARK: - Public
    // MARK: - Private
}
