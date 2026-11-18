//
//  ProcedureConvertibleTests.swift
//  WarpTests
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A module of procedures that name themselves")
struct ProcedureConvertibleTests {
    private struct Point: ValueRepresentable {
        // MARK: - Property
        static let name: Name = "App.Point"
        static let type = TypeExpression.named(name)
        static let declaration: TypeDeclaration? = .struct(["x": Int.type, "y": Int.type])

        let x: Int
        let y: Int

        var value: Value {
            get throws {
                let fields: [(name: Name, value: Value)] = [(name: "x", value: x.value), (name: "y", value: y.value)]

                return try Value.holding(fields, named: Self.name)
            }
        }

        // MARK: - Initializer
        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }

        init(_ value: Value) throws {
            self.x = try Int(value["x"] ?? .null)
            self.y = try Int(value["y"] ?? .null)
        }

        // MARK: - Public
        // MARK: - Private
    }

    // Another Swift type writing `App.Point`, declared alike.
    private struct OtherPoint: ValueRepresentable {
        // MARK: - Property
        static let type = Point.type
        static let declaration = Point.declaration

        let point: Point

        var value: Value {
            get throws { try point.value }
        }

        // MARK: - Initializer
        init(_ value: Value) throws {
            self.point = try Point(value)
        }

        // MARK: - Public
        // MARK: - Private
    }

    // A declaration written for a type that is no name.
    private struct ListedList: ValueRepresentable {
        // MARK: - Property
        static let type = TypeExpression.array(.int)
        static let declaration = Point.declaration

        var value: Value { .array([]) }

        // MARK: - Initializer
        init(_ value: Value) throws {}

        // MARK: - Public
        // MARK: - Private
    }

    // Moves a point one step right.
    private struct StepProcedure: ProcedureConvertible, Query {
        enum Parameters: Int, ParameterSet {
            case point

            // MARK: - Property
            var declared: Parameter { Parameter(name: "point", type: Point.type) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let name: Name

        var procedure: Procedure {
            Procedure(signature: Signature(of: Self.self, returns: Point.type), implementation: self)
        }

        // MARK: - Initializer
        init(name: Name = "App.step") {
            self.name = name
        }

        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            let point = try Point(question[.point])

            return try Point(x: point.x + 1, y: point.y).value
        }

        // MARK: - Private
    }

    // Declares a String and reads an Int, a Swift type its declaration does
    // not write.
    private struct MisreadProcedure: ProcedureConvertible, Query {
        enum Parameters: Int, ParameterSet {
            case text

            // MARK: - Property
            var declared: Parameter { Parameter(name: "text", type: .string) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let name: Name = "App.misread"

        var procedure: Procedure {
            Procedure(signature: Signature(of: Self.self, returns: .int), implementation: self)
        }

        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try Int(question[.text]).value
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("the module declares each one under its name, and each type it lists")
    func declares() throws {
        // Given
        let procedures: [any ProcedureConvertible] = [StepProcedure()]

        // When
        let sut = try Module(types: [Point.self], procedures: procedures)

        // Then
        #expect(sut.procedures["App.step"] != nil)
        #expect(sut.types == [Point.name: try #require(Point.declaration)])
    }

    @Test("a type the signatures name and the module does not list is one it imports")
    func importsATypeItDoesNotList() throws {
        // Given
        let procedures: [any ProcedureConvertible] = [StepProcedure()]

        // When
        let sut = try Module(procedures: procedures)

        // Then
        #expect(sut.types.isEmpty)
        #expect(sut.imports.contains(Point.name))
    }

    @Test("a run calls one as it calls any procedure")
    func runs() async throws {
        // Given
        let entry = Procedure(
            access: .public,
            signature: Signature(parameters: [Parameter(name: "point", type: Point.type)], returns: Point.type),
            body: [
                returning(.call(Call(selector: "App.step", arguments: [.reference([.name("point")])])))
            ]
        )
        let sut = try Module(types: [Point.self], procedures: [StepProcedure()])

        // When
        let output = try await run(
            [sut, try Module(procedures: ["entry": entry])],
            arguments: ["point": try Point(x: 1, y: 2).value]
        )

        // Then
        #expect(try Point(output).x == 2)
    }

    @Test("a value a native cannot read is refused where the run was")
    func refusesWhereTheRunWas() async throws {
        // Given
        let entry = Procedure(
            access: .public,
            signature: Signature(returns: .int),
            body: [
                returning(.call(Call(selector: "App.misread", arguments: [.literal(.string("one"))])))
            ]
        )
        let sut = try Module(procedures: [MisreadProcedure()])

        // When
        let refusal = await #expect(throws: ValueRefused.self) {
            try await run([sut, try Module(procedures: ["entry": entry])])
        }

        // Then
        #expect(refusal?.trace != nil)
    }

    @Test("modules sharing a Swift type run where one of them declares it")
    func sharesATypeOneModuleDeclares() async throws {
        // Given
        let entry = Procedure(
            access: .public,
            signature: Signature(parameters: [Parameter(name: "point", type: Point.type)], returns: Point.type),
            body: [
                Statement(
                    binding: .constant("moved"),
                    expression: .call(Call(selector: "App.step", arguments: [.reference([.name("point")])]))
                ),
                returning(.call(Call(selector: "App.again", arguments: [.reference([.name("moved")])])))
            ]
        )
        let declaring = try Module(types: [Point.self], procedures: [StepProcedure()])
        let sut = try Module(procedures: [StepProcedure(name: "App.again")])

        // When
        let output = try await run(
            [declaring, sut, try Module(procedures: ["entry": entry])],
            arguments: ["point": try Point(x: 1, y: 2).value]
        )

        // Then
        #expect(try Point(output).x == 3)
    }

    @Test("a build where no module declares a type a signature names is refused")
    func refusesATypeNobodyDeclares() async throws {
        // Given
        let entry = Procedure(
            access: .public,
            signature: Signature(parameters: [Parameter(name: "point", type: Point.type)], returns: Point.type),
            body: [
                returning(.call(Call(selector: "App.step", arguments: [.reference([.name("point")])])))
            ]
        )
        let sut = try Module(procedures: [StepProcedure()])

        // When
        let refusal = await #expect(throws: BuildRefused.self) {
            try await run([sut, try Module(procedures: ["entry": entry])])
        }

        // Then
        #expect(refusal?.message.contains("'\(Point.name)'") == true)
    }

    @Test("two modules declaring one Swift type are refused")
    func refusesATypeTwoModulesDeclare() async throws {
        // Given
        let one = try Module(types: [Point.self], procedures: [StepProcedure()])
        let other = try Module(types: [Point.self], procedures: [StepProcedure(name: "App.again")])

        // When
        // Then
        await #expect(throws: BuildRefused.self) {
            try await run([one, other])
        }
    }

    @Test("a Swift type listed twice is one type")
    func declaresATypeListedTwiceOnce() throws {
        // Given
        let types: [any ValueRepresentable.Type] = [Point.self, Point.self]

        // When
        let sut = try Module(types: types, procedures: [StepProcedure()])

        // Then
        #expect(sut.types.count == 1)
    }

    @Test("two Swift types writing one name are refused, however alike they declare it")
    func refusesTwoSwiftTypesUnderOneName() {
        // Given
        let types: [any ValueRepresentable.Type] = [Point.self, OtherPoint.self]

        // When
        // Then
        #expect(throws: ValidationError.self) { try Module(types: types, procedures: [StepProcedure()]) }
    }

    @Test("a declaration for a type that is no name is refused")
    func refusesADeclarationForNoName() {
        // Given
        let types: [any ValueRepresentable.Type] = [ListedList.self]

        // When
        // Then
        #expect(throws: ValidationError.self) { try Module(types: types, procedures: [StepProcedure()]) }
    }

    @Test("a Swift type with no declaration is refused where the module lists what it declares")
    func refusesATypeThatDeclaresNothing() {
        // Given
        let types: [any ValueRepresentable.Type] = [Int.self]

        // When
        // Then
        #expect(throws: ValidationError.self) { try Module(types: types, procedures: [StepProcedure()]) }
    }

    @Test("a name declared twice is refused")
    func refusesANameTwice() {
        // Given
        let procedures: [any ProcedureConvertible] = [StepProcedure(), StepProcedure()]

        // When
        // Then
        #expect(throws: ValidationError.self) { try Module(procedures: procedures) }
    }

    // MARK: - Private
}
