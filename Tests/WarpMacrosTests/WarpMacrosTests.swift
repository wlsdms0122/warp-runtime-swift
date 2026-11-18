//
//  WarpMacrosTests.swift
//  WarpMacrosTests
//

import Foundation
import Testing
import Warp
import WarpMacros
import WarpTestSupport

@ValueRepresentable("App.Point")
private struct Point: Equatable {
    let x: Int
    let y: Int?
}

@ValueRepresentable("App.Setting")
private struct Setting {
    let `default`: Int
    var count: Int {
        didSet {}
    }
    var doubled: Int { count * 2 }
}

@ValueRepresentable("App.Segment")
private struct Segment: Equatable {
    let from: Point
    let to: Point
    let labels: [String]
}

@ValueRepresentable("App.Node")
private struct Node: Equatable {
    let n: Int
    let children: [Node]
}

@ValueRepresentable("App.Parent")
private struct Parent {
    let children: [Child]
}

@ValueRepresentable("App.Child")
private struct Child {
    let parents: [Parent]
}

@ValueRepresentable("App.Corner")
private struct FlatCorner {
    let x: Int
    let y: Int
}

@ValueRepresentable("App.Corner")
private struct DeepCorner {
    let x: Int
    let y: Int
    let z: Int
}

@ValueRepresentable("App.Box")
private struct Box {
    let near: FlatCorner
    let far: DeepCorner
}

// Moves a point by a distance.
@ProcedureConvertible("App.step")
private struct StepProcedure: Query {
    func evaluate(point: Point, by distance: Int) async throws -> Point {
        Point(x: point.x + distance, y: point.y)
    }
}

// Answers from what its call wrote alone.
@ProcedureConvertible("App.shout", constness: .const)
private struct ShoutProcedure: Computation {
    func compute(text: String) -> String {
        text.uppercased()
    }
}

// Grows a tree as deep as asked.
@ProcedureConvertible("App.grow")
private struct GrowProcedure: Computation {
    func compute(depth: Int) -> Node {
        Node(n: depth, children: depth == 0 ? [] : [compute(depth: depth - 1)])
    }
}

// Returns a parent whose children name it back.
@ProcedureConvertible("App.parent")
private struct ParentProcedure: Computation {
    func compute() -> Parent {
        Parent(children: [])
    }
}

// Returns a box whose corners declare one name two ways.
@ProcedureConvertible("App.box")
private struct BoxProcedure: Computation {
    func compute() -> Box {
        Box(near: FlatCorner(x: 0, y: 0), far: DeepCorner(x: 1, y: 1, z: 1))
    }
}

// Returns nothing and reads the run's context.
@ProcedureConvertible("App.note", failing: .these(["app_failed"]))
private struct NoteProcedure: Effect {
    func run(_ text: String, invocation: Invocation<Self>) async throws {
        guard invocation.selector == "App.note" else { throw RunRefused("sent under another name") }
    }
}

@Suite("Conformances written from Swift declarations")
struct WarpMacrosTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a struct declares the fields its stored properties are")
    func declaresAStruct() throws {
        // Given
        let sut = Segment.self

        // When
        let declaration = sut.declaration

        // Then
        #expect(sut.type == .named("App.Segment"))
        #expect(declaration == .struct(["from": .named("App.Point"), "to": .named("App.Point"), "labels": .array(.string)]))
    }

    @Test("a module declares the structs it lists")
    func declaresWhatAModuleLists() throws {
        // Given
        let procedures: [any ProcedureConvertible] = [StepProcedure()]

        // When
        let sut = try Module(types: [Point.self], procedures: procedures)

        // Then
        #expect(sut.types == ["App.Point": .struct(["x": .int, "y": .optional(.int)])])
    }

    @Test("a field's struct the module does not list is one it imports")
    func importsAFieldStructItDoesNotList() throws {
        // Given
        let types: [any ValueRepresentable.Type] = [Segment.self]

        // When
        let sut = try Module(types: types, procedures: [])

        // Then
        #expect(Set(sut.types.keys) == ["App.Segment"])
        #expect(sut.imports.contains("App.Point"))
    }

    @Test("a struct written out reads back as what it was")
    func roundTrip() throws {
        // Given
        let sut = Segment(from: Point(x: 1, y: nil), to: Point(x: 2, y: 3), labels: ["a"])

        // When
        let read = try Segment(try sut.value)

        // Then
        #expect(read == sut)
    }

    @Test("a field takes the property's name unescaped, an observed property is stored and a computed one is not")
    func readsStoredProperties() throws {
        // Given
        let sut = Setting.self

        // When
        let declaration = sut.declaration

        // Then
        #expect(declaration == .struct(["default": .int, "count": .int]))
    }

    @Test("a struct naming itself declares a field of its own name")
    func declaresAStructNamingItself() throws {
        // Given
        let procedures: [any ProcedureConvertible] = [GrowProcedure()]

        // When
        let sut = try Module(types: [Node.self], procedures: procedures)

        // Then
        #expect(sut.types == ["App.Node": .struct(["n": .int, "children": .array(.named("App.Node"))])])
    }

    @Test("two structs naming each other each declare a field of the other's name")
    func declaresStructsNamingEachOther() throws {
        // Given
        let procedures: [any ProcedureConvertible] = [ParentProcedure()]

        // When
        let sut = try Module(types: [Parent.self, Child.self], procedures: procedures)

        // Then
        #expect(sut.types == [
            "App.Parent": .struct(["children": .array(.named("App.Child"))]),
            "App.Child": .struct(["parents": .array(.named("App.Parent"))])
        ])
    }

    @Test("two structs declaring one name are refused")
    func refusesANameTwoStructsDeclare() {
        // Given
        let types: [any ValueRepresentable.Type] = [Box.self, FlatCorner.self, DeepCorner.self]

        // When
        // Then
        #expect(throws: ValidationError.self) { try Module(types: types, procedures: [BoxProcedure()]) }
    }

    @Test("a struct of another name is refused")
    func refusesAnotherStruct() throws {
        // Given
        let sut = try Value.holding([(name: "x", value: .int(1)), (name: "y", value: .null)], named: "App.Other")

        // When
        // Then
        #expect(throws: ValueRefused.self) { try Point(sut) }
    }

    @Test("a procedure declares its parameters, return type and the rest of its signature")
    func declaresAProcedure() throws {
        // Given
        let sut = StepProcedure()

        // When
        let step = sut.procedure.signature
        let shout = ShoutProcedure().procedure.signature
        let note = NoteProcedure().procedure.signature

        // Then
        #expect(step.parameters == [Parameter(name: "point", type: .named("App.Point")), Parameter(name: "by", type: .int)])
        #expect(step.returns == .named("App.Point"))
        #expect(shout.constness == .const)
        #expect(note.returns == .null)
        #expect(note.failing == .these(["app_failed"]))
        #expect(note.names == ["text"])
    }

    @Test("a run calls each kind through the function it wrote")
    func runs() async throws {
        // Given
        let entry = Procedure(
            access: .public,
            signature: Signature(
                parameters: [Parameter(name: "start", type: Point.type)],
                returns: .any,
                failing: .these(["app_failed"])
            ),
            body: [
                Statement(binding: .constant("noted"), expression: .call(Call(selector: "App.note", arguments: [.literal(.string("a"))]))),
                returning(
                    dictionary([
                        "step": .call(Call(selector: "App.step", arguments: [.reference([.name("start")]), .literal(.int(2))])),
                        "shout": .call(Call(selector: "App.shout", arguments: [.literal(.string("hi"))]))
                    ])
                )
            ]
        )
        let sut = try Module(types: [Point.self], procedures: [StepProcedure(), ShoutProcedure(), NoteProcedure()])
        let start = try Point(x: 1, y: nil).value

        // When
        let output = try await run(
            [sut, try Module(procedures: ["entry": entry])],
            arguments: ["start": start]
        )

        // Then
        #expect(try Point(output.dictionaryValue?["step"] ?? .null) == Point(x: 3, y: nil))
        #expect(output.dictionaryValue?["shout"] == .string("HI"))
    }

    @Test("a run returns a struct naming itself")
    func runsAStructNamingItself() async throws {
        // Given
        let entry = Procedure(
            access: .public,
            signature: Signature(returns: Node.type),
            body: [
                returning(.call(Call(selector: "App.grow", arguments: [.literal(.int(2))])))
            ]
        )
        let sut = try Module(types: [Node.self], procedures: [GrowProcedure()])

        // When
        let output = try await run([sut, try Module(procedures: ["entry": entry])])

        // Then
        #expect(try Node(output) == GrowProcedure().compute(depth: 2))
    }

    // MARK: - Private
}
