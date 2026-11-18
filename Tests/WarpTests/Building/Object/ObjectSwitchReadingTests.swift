//
//  ObjectSwitchReadingTests.swift
//  WarpTests
//
//  Created by JSilver on 11/1/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// What a reading of an object holding an enum and a switch refuses. Each test
// mutates one field of a real object, as the reading tests beside it do.
@Suite("An object whose enum or switch is not written as one")
struct ObjectSwitchReadingTests {
    private struct ObjectMissing: Error {
    }

    // MARK: - Property
    private let builder = Builder { compiled in Fingerprint(Array("\(try compiled.object())".utf8)) }

    // MARK: - Initializer
    // MARK: - Test
    @Test("is read back as it was written")
    func readBack() async throws {
        // Given
        let parts = try await parts()

        // When / Then
        _ = try Compiled(written: .dictionary(parts), of: nil)
    }

    @Test("is refused where a switch writes its arms out of name order")
    func armsOutOfOrder() async throws {
        // Given. The cases' names swapped and the code left where it was,
        // since the operation table holds each operation where it was written.
        let parts = try await naming { names in names.reverse() }

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a switch writes its arms out of name order, or one case twice")
        }
    }

    @Test("is refused where a switch writes one case's arm twice")
    func armTwice() async throws {
        // Given
        let parts = try await naming { names in names[1] = names[0] }

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a switch writes its arms out of name order, or one case twice")
        }
    }

    @Test("is refused where an arm binds its fields out of name order")
    func bindsOutOfOrder() async throws {
        // Given
        let parts = try await binding { binds in binds.reverse() }

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'binds' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where an arm binds one field twice")
    func bindTwice() async throws {
        // Given
        let parts = try await binding { binds in binds[1] = binds[0] }

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'binds' writes its names out of order, or one of them twice")
        }
    }

    @Test("is refused where an arm binds a field to a slot past the frame")
    func boundPastTheFrame() async throws {
        // Given
        let parts = try await binding { binds in
            guard case var .array(bind) = binds[0] else { return }

            bind[1] = .int(9)
            binds[0] = .array(bind)
        }

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("a body stands on a slot its frame of 3 does not hold")
        }
    }

    @Test("is refused where an enum declares no case")
    func noCase() async throws {
        // Given
        var parts = try await parts()

        guard case var .array(types) = parts["types"],
            case var .array(entry) = types[0],
            case var .array(declared) = entry[1],
            declared.first == .int(ObjectLayout.TypeTag.enum.rawValue)
        else {
            Issue.record("an object writes an enum under its tag in 'types'")

            return
        }

        declared[1] = .array([])
        entry[1] = .array(declared)
        types[0] = .array(entry)
        parts = parts.writing("types", with: .array(types))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("an enum declares no case")
        }
    }

    @Test("is refused where an enum is written as an entry of the type table")
    func enumAsAnEntry() async throws {
        // Given
        var parts = try await parts()

        guard case var .array(types) = parts["typeTable"], !types.isEmpty else {
            Issue.record("an object writes the types its rows stand on")

            return
        }

        types[0] = .array([.int(ObjectLayout.TypeTag.enum.rawValue), .array([.array([.string("a"), .array([])])])])
        parts = parts.writing("typeTable", with: .array(types))

        // When / Then
        #expect {
            try Compiled(written: .dictionary(parts), of: nil)
        } throws: { error in
            error is ObjectRefused && "\(error)".contains("'type' writes an enum")
        }
    }

    // MARK: - Private
    // The object with the switch's arms changed.
    private func switching(_ change: (inout [Value]) -> Void) async throws -> Value.Dictionary {
        var parts = try await parts()

        guard case var .array(operations) = parts["operationTable"],
            let number = operations.firstIndex(where: { operation in
                guard case let .array(fields) = operation else { return false }

                return fields.first == .int(ObjectLayout.OperationTag.switch.rawValue)
            }),
            case var .array(operation) = operations[number],
            case var .array(arms) = operation[3],
            arms.count == 2
        else {
            throw ObjectMissing()
        }

        change(&arms)
        operation[3] = .array(arms)
        operations[number] = .array(operation)
        parts = parts.writing("operationTable", with: .array(operations))

        return parts
    }

    // The object with the names of the switch's arms changed.
    private func naming(_ change: @escaping (inout [Value]) -> Void) async throws -> Value.Dictionary {
        try await switching { arms in
            var names = arms.compactMap { arm -> Value? in
                guard case let .array(fields) = arm else { return nil }

                return fields.first
            }

            change(&names)

            for (position, name) in zip(arms.indices, names) {
                guard case var .array(fields) = arms[position] else { continue }

                fields[0] = name
                arms[position] = .array(fields)
            }
        }
    }

    // The object with the binds of the arm binding two fields changed.
    private func binding(_ change: @escaping (inout [Value]) -> Void) async throws -> Value.Dictionary {
        try await switching { arms in
            guard case var .array(arm) = arms[1],
                case var .array(binds) = arm[1],
                binds.count == 2
            else {
                return
            }

            change(&binds)
            arm[1] = .array(binds)
            arms[1] = .array(arm)
        }
    }

    // A switch over an enum of two cases, the second binding both its fields.
    private func parts() async throws -> Value.Dictionary {
        let sut = try Module(
            types: ["App.Shape": .enum(["dot": [:], "rect": ["h": .int, "w": .int]])],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "s", type: .named("App.Shape"))], returns: .int),
                    body: [
                        Statement(
                            expression: .switch(
                                reference("s"),
                                cases: [
                                    "dot": Arm(then: [returning(.literal(.int(0)))]),
                                    "rect": Arm(binds: ["h": "a", "w": "b"], then: [returning(reference("a"))])
                                ],
                                default: nil
                            )
                        )
                    ]
                )
            ]
        )

        let compiled = try await builder.compile([sut] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("App.entry") }),
            case let .dictionary(written) = try mine.object()
        else {
            throw ObjectMissing()
        }

        return written
    }
}
