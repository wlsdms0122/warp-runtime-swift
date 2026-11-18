//
//  WarpMacrosDiagnosticTests.swift
//  WarpMacrosTests
//

import Foundation
import Testing
#if canImport(WarpMacrosPlugin)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import WarpMacrosPlugin

@Suite("What the macros refuse to write")
struct WarpMacrosDiagnosticTests {
    // MARK: - Property
    let macros: [String: any Macro.Type] = [
        "ValueRepresentable": ValueRepresentableMacro.self,
        "ProcedureConvertible": ProcedureConvertibleMacro.self
    ]

    // MARK: - Initializer
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a procedure adopting none of the three kinds is refused")
    func refusesWithoutAKind() {
        // Given
        let source = """
            @ProcedureConvertible("App.step")
            struct StepProcedure {
                func run(point: Int) -> Int { point }
            }
            """

        // When
        // Then
        assertMacroExpansion(
            source,
            expandedSource: """
                struct StepProcedure {
                    func run(point: Int) -> Int { point }
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ProcedureConvertible goes on a type adopting one of Effect, Query and Computation",
                    line: 1,
                    column: 1
                )
            ],
            macros: macros
        )
    }

    @Test("a procedure without its work under the kind's verb is refused")
    func refusesWithoutWork() {
        // Given
        let source = """
            @ProcedureConvertible("App.step")
            struct StepProcedure: Query {
                func step(point: Int) -> Int { point }
            }
            """

        // When
        // Then
        assertMacroExpansion(
            source,
            expandedSource: """
                struct StepProcedure: Query {
                    func step(point: Int) -> Int { point }
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ProcedureConvertible reads one function named 'evaluate' with labeled parameters",
                    line: 1,
                    column: 1
                )
            ],
            macros: macros
        )
    }

    @Test("a stored property without its type written is refused")
    func refusesAnUnwrittenType() {
        // Given
        let source = """
            @ValueRepresentable("App.Count")
            struct Count {
                var value = 0
            }
            """

        // When
        // Then
        assertMacroExpansion(
            source,
            expandedSource: """
                struct Count {
                    var value = 0
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ValueRepresentable reads a field's type from its property, and 'value' writes none",
                    line: 1,
                    column: 1
                )
            ],
            macros: macros
        )
    }

    @Test("a value standing for a declared struct is a struct")
    func refusesAnythingButAStruct() {
        // Given
        let source = """
            @ValueRepresentable("App.Kind")
            enum Kind {
                case one
            }
            """

        // When
        // Then
        assertMacroExpansion(
            source,
            expandedSource: """
                enum Kind {
                    case one
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@ValueRepresentable stands a struct for a declared struct", line: 1, column: 1)
            ],
            macros: macros
        )
    }

    // MARK: - Private
}
#endif
