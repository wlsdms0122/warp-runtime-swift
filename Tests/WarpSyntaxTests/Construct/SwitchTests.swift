//
//  SwitchTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 11/1/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

@Suite("A switch runs the arm its case names")
struct SwitchTests {
    // MARK: - Property
    private let loader = Loader()

    private static let program = """
    (warp 1)
    (enum App.Target
      (case local)
      (case remote (field host String) (field port Int))
      (case unix (field path String)))
    (procedure entry
      (access public)
      (parameter target (type App.Target))
      (returns Int)
      (body
        (switch target
          (case remote
            (bind port p)
            (then
              (return p)))
          (default
            (return 0)))))

    """

    private static let echo = """
    (warp 1)
    (enum App.Target
      (case local)
      (case remote (field host String) (field port Int)))
    (procedure entry
      (access public)
      (parameter target (type App.Target))
      (returns App.Target)
      (body
        (return target)))

    """

    // MARK: - Initializer
    // MARK: - Test
    @Test("the arm a case names runs with the fields it binds, and the default runs for the cases no arm names")
    func theArmItsCaseNamesRuns() async throws {
        // Given
        let module = try loader.loadDocument(try TextEncoding().value(from: Self.program))
        let remote = Value.struct(Struct(name: "App.Target.remote", ["host": .string("a"), "port": .int(8080)]))
        let local = Value.struct(Struct(name: "App.Target.local", [:]))

        // When
        let bound = try await run(module, arguments: ["target": remote])
        let defaulted = try await run(module, arguments: ["target": local])

        // Then
        #expect(bound == .int(8080))
        #expect(defaulted == .int(0))
    }

    @Test("a case from outside is fitted to its case, a field the case never named left out, and leaves under its spelling")
    func aCaseFromOutsideIsFittedAtTheDoor() async throws {
        // Given
        let module = try loader.loadDocument(try TextEncoding().value(from: Self.echo))
        let remote = Value.struct(
            Struct(name: "App.Target.remote", ["host": .string("a"), "port": .int(8080), "scheme": .string("tcp")])
        )

        // When
        let returned = try await run(module, arguments: ["target": remote])

        // Then
        #expect(returned == .struct(Struct(name: "App.Target.remote", ["host": .string("a"), "port": .int(8080)])))
    }

    @Test("a struct from outside under the enum's own name refuses at the run")
    func theEnumsOwnNameRefusesAtTheDoor() async throws {
        // Given
        let module = try loader.loadDocument(try TextEncoding().value(from: Self.echo))

        // When / Then
        await #expect {
            try await run(module, arguments: ["target": .struct(Struct(name: "App.Target", [:]))])
        } throws: { error in
            "\(error)".contains("an enum's name declares no struct")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
