//
//  TextEncodingTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax
import WarpTestSupport

// The text a document and a case are written in. One tree, one text: the
// writer lays a tree out one way and refuses one no node writes back, and the
// reader takes any layout of the same nodes.
@Suite("The text encoding")
struct TextEncodingTests {
    // MARK: - Property
    private static let golden = """
    (warp 1)
    (import Standard.Numeric.plus)

    (procedure entry
      (access public)
      (parameter n (type Int))
      (returns Int)
      (body
        (return (call Standard.Numeric.plus n 1))))

    """

    private static let everyNode = """
    (warp 1)
    (description "Every node.")
    (import App.Point Hashable)
    (import Standard.Numeric.plus)
    (const seven 7)
    (var count (type Int) 0)
    (var names (array))

    (struct App.Box
      (typeParameter K App.Named Hashable)
      (typeParameter V)
      (satisfies App.Named)
      (field balance (var Int))
      (field items (dictionary K V))
      (type Item K)
      (procedure area
        (parameter self (type Self))
        (returns Int)
        (body
          (return 1))))
    (type App.Id Int)

    (contract App.Named
      (type Item Hashable)
      (type Key)
      (procedure name
        (const)
        (parameter self (type Self))
        (returns String)))

    (extension
      (head (array (some T Hashable)))
      (satisfies App.Named)
      (procedure name
        (parameter self (type Self))
        (returns String)
        (body
          (return "array"))))

    (procedure App.g
      (description "Everything a procedure holds.")
      (access public)
      (const)
      (isolated)
      (parameter c (type (some C App.Container)) (description "a container"))
      (parameter f (type (procedure (const) (parameters) (failing (anything)) (returns Int))))
      (parameter any)
      (returns (nullable Int))
      (failing (anything))
      (bound C.Item Hashable Equatable)
      (sameType C.Key Int)
      (body
        (let x (type Double) 1.5)
        (var y)
        (var z 2)
        (set (path a (field b) (index 0)) x)
        (call Standard.Numeric.plus 1 x)
        (let w
          (loop
            (while (as? x Bool))
            (body
              (conditional
                (when (as x Bool))
                (then
                  (break w))
                (else
                  (continue))))))
        (let r
          (attempt
            (body
              (apply (apply f) `null`))
            (rescue
              (break))))
        (return (array 1 "a" x"6a" null -2.5))
        (struct (field x 1))
        (dictionary (entry "k" (struct App.Point (field x 1))))
        (closure
          (returns Int)
          (body
            (return 1)))
        (return x)))

    """

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document's text reads to the tree its loader takes, and is written back the same")
    func theGoldenText() throws {
        // When
        let sut = try TextEncoding().value(from: Self.golden)

        // Then
        _ = try Loader().load(sut, identity: nil)
        #expect(try TextEncoding().text(from: sut) == Self.golden)
    }

    @Test("every node reads to its tree and is written back as itself")
    func everyNodeComesBack() throws {
        // When
        let sut = try TextEncoding().value(from: Self.everyNode)

        // Then
        #expect(try TextEncoding().text(from: sut) == Self.everyNode)

        guard case let .dictionary(document) = sut, case let .dictionary(procedures)? = document["procedures"] else {
            Issue.record("expected a document holding procedures, got \(sut)")

            return
        }

        guard case let .dictionary(procedure)? = procedures["App.g"] else {
            Issue.record("expected App.g, got \(procedures)")

            return
        }

        #expect(procedure["failing"] == .string("anything"))
        #expect(procedure["returns"] == .string("Int?"))
        #expect(procedure["bounds"] == .dictionary(["C.Item": .string("Hashable & Equatable")]))
        #expect(document["imports"] == .array([.string("App.Point: Hashable"), .string("Standard.Numeric.plus")]))
    }

    @Test("layout is free on the way in: any white space and a mapping's parts in any order read to one tree")
    func anyLayoutReadsToOneTree() throws {
        // Given
        let laid = """
        (warp 1) (procedure entry (body (return (call Standard.Numeric.plus n 1)))
           (returns Int) (parameter n (type Int)) (access public))
              (import Standard.Numeric.plus)
        """

        // When / Then
        #expect(try TextEncoding().value(from: laid) == TextEncoding().value(from: Self.golden))
    }

    @Test("a key or a name written twice is refused")
    func writtenTwiceIsRefused() {
        // Given
        for text in [
            "(warp 1) (description \"a\") (description \"b\")",
            "(warp 1) (procedure f) (procedure f)",
            "(warp 1) (procedure f (const) (const))",
            "(warp 1) (procedure f (bound C.Item `A & B`))",
            "(warp 1) (import App.P `B & `)",
            "(test 1) (expect (answers (dictionary (entry 1 1) (entry 1.0 2))))"
        ] {
            // When / Then
            #expect(throws: EncodingRefused.self, "\(text)") { try TextEncoding().value(from: text) }
        }
    }

    @Test("a statement the load refuses for what it says is read and written back as itself")
    func aStatementTheLoadRefusesIsWritten() throws {
        // Given
        for statement in ["(let x)", "(let x (type Int))", "(set x)", "(set x (type Int) 1)"] {
            let text = "(warp 1)\n\n(procedure f\n  (body\n    \(statement)))\n"

            // When
            let read = try TextEncoding().value(from: text)

            // Then
            #expect(try TextEncoding().text(from: read) == text)
        }
    }

    @Test("a word stands where no name could, and a name is never a word")
    func aWordIsNeverAName() throws {
        // When
        let anything = try TextEncoding().value(from: "(warp 1) (procedure f (failing anything))")
        let named = try TextEncoding().value(from: "(warp 1) (procedure f (body (let w (loop (body (break `null`))))))")

        // Then
        #expect(anything == .dictionary([
            "warp": .int(1),
            "imports": .array([]),
            "procedures": .dictionary(["f": .dictionary(["failing": .array([.string("anything")])])])
        ]))
        #expect(try TextEncoding().text(from: named).contains("(break `null`)"))
        #expect(throws: EncodingRefused.self) {
            try TextEncoding().value(from: "(warp 1) (procedure f (body (let w (loop (body (break null))))))")
        }
    }

    @Test("a text begins with what it is")
    func aTextBeginsWithWhatItIs() throws {
        // When / Then
        #expect(try TextEncoding().value(from: "(test 1)") == .dictionary(["test": .int(1)]))

        for text in ["", "(import a) (warp 1)", "warpt 1\n{}", "\u{feff}(warp 1)"] {
            #expect {
                try TextEncoding().value(from: text)
            } throws: { error in
                "\(error)".contains("a text begins with what it is")
            }
        }
    }

    @Test("a tree no node writes back is refused on the way out")
    func aTreeNoNodeWritesIsRefused() {
        // Given
        let document: [Name: Value] = ["warp": .int(1), "imports": .array([])]

        for tree in [
            Value.dictionary(document.merging(["budget": .int(1)]) { one, _ in one }),
            Value.dictionary(["imports": .array([])]),
            Value.dictionary(["warp": .int(1)]),
            Value.dictionary(document.merging(["const": .dictionary(["x": .dictionary(["a": .int(1)])])]) { one, _ in one }),
            Value.dictionary(document.merging(["types": .dictionary(["T": .string("Array<Int,Int>")])]) { one, _ in one }),
            Value.dictionary(document.merging(["const": .dictionary(["x": .double(.nan)])]) { one, _ in one }),
            Value.dictionary(document.merging([
                "types": .dictionary(["T": .string(String(repeating: "Array<", count: 5_000) + "Int" + String(repeating: ">", count: 5_000))])
            ]) { one, _ in one }),
            Value.int(1)
        ] {
            // When / Then
            #expect(throws: EncodingRefused.self, "\(tree)") { try TextEncoding().text(from: tree) }
        }
    }

    @Test("a case writes a program no node writes as its tree, and only such a program")
    func aCaseCarriesATree() throws {
        // Given
        let program = Value.dictionary(["warp": .int(1), "imports": .array([]), "budget": .int(1)])
        let tree = Value.dictionary([
            "test": .int(1),
            "program": program,
            "expect": .dictionary(["refuses": .string("load")])
        ])

        // When
        let sut = try TextEncoding().text(from: tree)

        // Then
        #expect(sut == """
        (test 1)
        (tree (dictionary (entry "budget" 1) (entry "imports" (array)) (entry "warp" 1)))
        (expect (refuses load))

        """)
        #expect(try TextEncoding().value(from: sut) == tree)
        #expect(throws: EncodingRefused.self) {
            try TextEncoding().value(from: "(test 1) (tree (dictionary (entry \"warp\" 1) (entry \"imports\" (array))))")
        }
    }

    @Test("a case's text reads to its tree and is written back the same")
    func aCaseComesBack() throws {
        // Given
        let text = """
        (test 1)
        (name "n")
        (note "a note")

        (documents
          (document
            (warp 1)
            (const one 1)))

        (vocabulary
          (procedure Lib.f
            (parameter first (type Int))
            (returns Int)
            (answers 5)))

        (program
          (warp 1)
          (procedure entry
            (access public)
            (body
              (return 1))))
        (arguments (argument c false))
        (expect (answers (dictionary (entry "a" (array 1)) (entry x"00" (struct App.Point (field x 1))))))

        """

        // When
        let sut = try TextEncoding().value(from: text)

        // Then
        #expect(try TextEncoding().text(from: sut) == text)
    }

    @Test("a refusal says the line and column the reader stood at")
    func aRefusalIsPlaced() {
        // When / Then
        #expect {
            try TextEncoding().value(from: "(warp 1)\n(procedure f\n  (budget 1))\n")
        } throws: { error in
            (error as? EncodingRefused)?.position == EncodingRefused.Position(line: 3, column: 3)
        }

        #expect {
            try TextEncoding().value(from: "(warp 1)\n(const x \"a\"b)\n")
        } throws: { error in
            (error as? EncodingRefused)?.position == EncodingRefused.Position(line: 2, column: 13)
        }
    }

    @Test("bytes that are not UTF-8 are refused before they are text")
    func notUTF8IsRefused() {
        // When / Then
        #expect(throws: EncodingRefused.self) { try TextEncoding().value(from: Data([0x28, 0xff, 0x29])) }
    }

    // MARK: - Public
    // MARK: - Private
}
