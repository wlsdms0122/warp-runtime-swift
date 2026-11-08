//
//  RunPlaceTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 11/2/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard
import WarpTestSupport

// A run's refusal names a place for each frame that was running a statement,
// the outermost first, under WARP-72, each read in the keys the document
// writes, the place WARP-65 names.
@Suite("A run's refusal names the places of the frames it stopped in")
struct RunPlaceTests {
    // A document read from its text, and the identity its places stand in.
    private struct Written {
        // MARK: - Property
        let module: Module
        let identity: Identity

        // MARK: - Initializer
        init(_ text: String) throws {
            let document = try TextEncoding().value(from: text)

            self.module = try Loader().load(document)
            self.identity = try Identity.of(document)
        }

        // MARK: - Public
        // A place in this document, as WARP-65 writes one.
        func at(_ steps: [Value]) -> Value? {
            [.bytes(identity.bytes), .array(steps)]
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a refusal under a conditional names the statement under then")
    func aRefusalUnderThenNamesTheInnerStatement() async throws {
        // Given. The second statement of entry is a conditional, and the
        // first statement under its then reads past the array.
        let sut = try Written("""
            (warp 1)
            (import Standard.Comparable.lessThan)
            (procedure entry
              (access public)
              (parameter i (type Int))
              (returns Int)
              (body
                (let xs (array 1 2))
                (conditional
                  (when (call Standard.Comparable.lessThan 0 i))
                  (then
                    (let picked (path xs (index i)))
                    (return picked)))
                (return 0)))
            """)

        // When
        let places = try await Self.places(running: sut, arguments: ["i": .int(5)])

        // Then
        #expect(places == [sut.at(["procedures", "entry", "body", 1, "value", "conditional", "then", 0])])
    }

    @Test("a refusal in a closure a procedure writes names each closure's body, the inner one counted first")
    func aRefusalInAProceduresClosureNamesItsBody() async throws {
        // Given. entry writes `pick`, which writes `read` inside it, so `read`
        // is the first closure entry's numbering counts and `pick` the second.
        let sut = try Written("""
            (warp 1)
            (procedure entry
              (access public)
              (parameter i (type Int))
              (returns Int)
              (body
                (let pick
                  (closure
                    (parameter at (type Int))
                    (returns Int)
                    (body
                      (let read
                        (closure
                          (parameter xs (type (array Int)))
                          (returns Int)
                          (body
                            (return (path xs (index at))))))
                      (return (apply read (array 1 2))))))
                (return (apply pick i))))
            """)

        // When
        let places = try await Self.places(running: sut, arguments: ["i": .int(5)])

        // Then
        let pick: [Value] = ["procedures", "entry", "body", 0, "value", "closure", "body"]

        #expect(
            places == [
                sut.at(["procedures", "entry", "body", 1]),
                sut.at(pick + [1]),
                sut.at(pick + [0, "value", "closure", "body", 0])
            ]
        )
    }

    @Test("a refusal in a closure a constant writes names the body under the constant")
    func aRefusalInAConstantsClosureNamesItsBody() async throws {
        // Given
        let sut = try Written("""
            (warp 1)
            (const pick
              (closure
                (const)
                (parameter at (type Int))
                (returns Int)
                (body
                  (let xs (array 1 2))
                  (return (path xs (index at))))))
            (procedure entry
              (access public)
              (parameter i (type Int))
              (returns Int)
              (body
                (return (apply pick i))))
            """)

        // When
        let places = try await Self.places(running: sut, arguments: ["i": .int(5)])

        // Then
        #expect(
            places == [
                sut.at(["procedures", "entry", "body", 0]),
                sut.at(["const", "pick", "closure", "body", 1])
            ]
        )
    }

    @Test("a refusal in a closure a variable written with its type starts as names the body under value")
    func aRefusalInATypedVariablesClosureNamesItsBody() async throws {
        // Given. A variable saying what it holds writes its start under
        // `value`, beside `type`.
        let sut = try Written("""
            (warp 1)
            (var pick
              (type (procedure (parameters Int) (returns Int)))
              (closure
                (parameter at (type Int))
                (returns Int)
                (body
                  (let xs (array 1 2))
                  (return (path xs (index at))))))
            (procedure entry
              (access public)
              (parameter i (type Int))
              (returns Int)
              (body
                (return (apply pick i))))
            """)

        // When
        let places = try await Self.places(running: sut, arguments: ["i": .int(5)])

        // Then
        #expect(
            places == [
                sut.at(["procedures", "entry", "body", 0]),
                sut.at(["var", "pick", "value", "closure", "body", 1])
            ]
        )
    }

    @Test("a refusal in a procedure Standard writes in Warp names it after the statement that called it")
    func aRefusalInAStandardBodyKeepsTheCaller() async throws {
        // Given. The absolute value of the least Int is past what an Int
        // holds, which the third statement of Standard's body computes.
        let sut = try Written("""
            (warp 1)
            (import Standard.Math.absolute)
            (procedure entry
              (access public)
              (parameter n (type Int))
              (returns Int)
              (body
                (let made (call Standard.Math.absolute n))
                (return made)))
            """)
        let standard = try #require(
            Module.standard.first { module in
                module.procedures["Standard.Math.absolute"]?.implementation.body != nil
            }?.identity
        )

        // When
        let places = try await Self.places(running: sut, arguments: ["n": .int(Int.min)])

        // Then
        #expect(
            places == [
                sut.at(["procedures", "entry", "body", 0]),
                .array([.bytes(standard.bytes), ["procedures", "Standard.Math.absolute", "body", 2]])
            ]
        )
    }

    @Test("a refusal at the entry's door names no place")
    func aRefusalAtTheDoorNamesNothing() async throws {
        // Given
        let sut = try Written("""
            (warp 1)
            (procedure entry
              (access public)
              (parameter i (type Int))
              (returns Int)
              (body
                (return i)))
            """)

        // When
        let places = try await Self.places(running: sut, arguments: ["i": "five"])

        // Then
        #expect(places == [])
    }

    @Test("two pieces of all refusing name the first piece in the list's order")
    func twoRefusingPiecesNameTheFirst() async throws {
        // Given. Both pieces read past the array, the second a statement later.
        let sut = try Written("""
            (warp 1)
            (import Standard.Concurrent.all)
            (procedure entry
              (access public)
              (isolated)
              (parameter i (type Int))
              (returns (array Int))
              (failing concurrent_failed)
              (body
                (let xs (array 1 2))
                (return
                  (call Standard.Concurrent.all
                    (array
                      (closure
                        (isolated)
                        (returns Int)
                        (body
                          (return (path xs (index i)))))
                      (closure
                        (isolated)
                        (returns Int)
                        (body
                          (let read (path xs (index i)))
                          (return read))))))))
            """)

        // When
        let places = try await Self.places(running: sut, arguments: ["i": .int(5)])

        // Then
        let pieces: [Value] = ["procedures", "entry", "body", 1, "value", "return", "call", "arguments", 0]

        #expect(
            places == [
                sut.at(["procedures", "entry", "body", 1]),
                sut.at(pieces + [0, "closure", "body", 0])
            ]
        )
    }

    // MARK: - Public
    // MARK: - Private
    // The places the run's refusal names, each as WARP-65 writes one.
    private static func places(
        running document: Written,
        arguments: [Name: Value]
    ) async throws -> [Value?] {
        let image = try await Builder().build([document.module] + Module.standard)

        let error = await #expect(throws: (any Error).self) {
            try await Executor().run(image, entry: entryName, arguments: arguments)
        }
        let refusal = try #require(error as? any WarpError)

        return refusal.places.map(\.value)
    }
}
