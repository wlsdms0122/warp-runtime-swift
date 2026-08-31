//
//  TypeNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite("How a document spells a type")
struct TypeNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a built-in reads as its own name, applied or not")
    func builtinsParse() throws {
        #expect(try TypeReader.parse("string") == .string)
        #expect(try TypeReader.parse("array") == .array(.any))
        #expect(try TypeReader.parse("array<string>") == .array(.string))
        #expect(try TypeReader.parse("object<array<int>>") == .object(.array(.int)))
        #expect(try TypeReader.parse("procedure") == .procedure(nil))
        #expect(try TypeReader.parse("never") == .never)
    }

    @Test("a range is spelled into the name, either bound optional")
    func rangesParse() throws {
        #expect(try TypeReader.parse("int(0...255)") == .ranged(.whole(from: 0, to: .through(255))))
        #expect(try TypeReader.parse("int(0...)") == .ranged(.whole(from: 0)))
        #expect(try TypeReader.parse("int(...255)") == .ranged(.whole(to: .through(255))))
        #expect(try TypeReader.parse("int(-10...-1)") == .ranged(.whole(from: -10, to: .through(-1))))
        #expect(
            try TypeReader.parse("array<int(0...255)>")
                == .array(.ranged(.whole(from: 0, to: .through(255))))
        )
        #expect(
            try TypeReader.parse("int(0...255)?")
                == .nullable(.ranged(.whole(from: 0, to: .through(255))))
        )
        #expect(
            try TypeReader.parse("int(9223372036854775807...)")
                == .ranged(.whole(from: Int.max))
        )

        // A bound past the word is a whole number's one spelling of a number
        // no int holds — refused as that fact, not as a spelling defect.
        #expect {
            try TypeReader.parse("int(18446744073709551615...)")
        } throws: { error in
            "\(error)".contains("past what an int holds")
        }
    }

    @Test("the far bound may be left outside, and the kind under it is written")
    func openRangesAndFractionsParse() throws {
        // `..<` says the far bound is outside — the half-open interval a
        // position below a length is written against.
        #expect(try TypeReader.parse("int(0..<256)") == .ranged(.whole(from: 0, to: .upTo(256))))
        #expect(try TypeReader.parse("int(..<0)") == .ranged(.whole(to: .upTo(0))))

        // A fraction range writes the kind it refines, and a bound is a value
        // of that kind: `1` spells a whole number and `1.0` a fraction, so
        // neither range can be written with the other's bounds.
        #expect(
            try TypeReader.parse("double(0.0...1.0)")
                == .ranged(.fraction(from: 0, to: .through(1)))
        )
        #expect(
            try TypeReader.parse("double(0.0..<1.0)")
                == .ranged(.fraction(from: 0, to: .upTo(1)))
        )
        #expect(try TypeReader.parse("double(0.0...)") == .ranged(.fraction(from: 0)))
        #expect(throws: TypeFormError.self) { try TypeReader.parse("double(0...1)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(0.0...1.0)") }
    }

    @Test("a range that is not one spelling of one range is refused")
    func malformedRangesAreRefused() {
        // Two dots are not the spelling, a bound is written once and
        // canonically, and a range with nothing in it says nothing.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(0..255)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(...)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(007...9)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(+1...9)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(0 ... 255)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(a...b)") }

        // `..<` says the far bound is outside, so there has to be one — and
        // `..<` with nothing on either side says nothing twice.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(0..<)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int(..<)") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("double(..<)") }
    }

    @Test("every range writes back out as the one spelling it was read from")
    func rangesRoundTrip() throws {
        // Given — `rendered` is the type's identity and what a document is
        // written with, so a range that read one way and wrote another would
        // be a shape a round trip changes.
        for written in [
            "int(0...255)", "int(0...)", "int(...255)", "int(-10...-1)",
            "int(0..<256)", "int(..<0)",
            "double(0.0...1.0)", "double(0.0..<1.0)", "double(0.0...)",
            "double(...1.0)", "double(-2.5..<2.5)"
        ] {
            #expect(try TypeReader.parse(written).rendered == written)
        }
    }

    @Test("a slot asks for purity by writing it in front")
    func purityIsWrittenAndRead() throws {
        // Given / When / Then
        #expect(try TypeReader.parse("pure procedure") == .procedure(nil, .pure))
        #expect(try TypeReader.parse("procedure") == .procedure(nil, .unstated))

        // Only a procedure answers without running, so only a procedure is
        // written pure.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("pure string") }
    }

    @Test("a type parameter is written some, and is not a declared name")
    func typeParametersAreWrittenAndRead() throws {
        // Given / When / Then
        #expect(try TypeReader.parse("some Element") == .variable(name: "Element"))
        #expect(try TypeReader.parse("array<some Element>") == .array(.variable(name: "Element")))

        // A bare name is looked up in the table of declared types; only `some`
        // says the call decides.
        #expect(try TypeReader.parse("Element") == .named("Element"))

        #expect(throws: TypeFormError.self) { try TypeReader.parse("some ") }
    }

    @Test("a trailing ? reads as the nullable of the whole spelling")
    func nullableParses() throws {
        #expect(try TypeReader.parse("int?") == .nullable(.int))
        #expect(try TypeReader.parse("string?") == .nullable(.string))
        #expect(try TypeReader.parse("array<int>?") == .nullable(.array(.int)))
        #expect(try TypeReader.parse("Task?") == .nullable(.named("Task")))

        // `?` wraps the whole spelling, so inside the brackets it is the
        // element that is nullable.
        #expect(try TypeReader.parse("array<int?>") == .array(.nullable(.int)))
    }

    @Test("a ? that says nothing new is refused")
    func uselessNullableIsRefused() throws {
        // Twice says it once too often; what already admits null gains
        // nothing; never admits nothing; a parameter stands for the whole
        // filled type.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("int??") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("null?") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("any?") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("never?") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("some T?") }
    }

    @Test("a signature bounds its type parameters once, in bounds")
    func aBoundIsDeclaredInTheSignature() throws {
        // Given — the slots name the parameter, and the signature says what
        // the name admits
        let sut = try loader.loadProcedure([
            "receiver": "of",
            "bounds": ["T": "Comparable"],
            "parameters": ["of": "some T", "value": "some T"],
            "returns": "some T",
            "result": ["ref": "of"]
        ])

        // Then — every occurrence carries the bound the signature declared
        let signature = sut.procedures[entryName]?.signature

        #expect(
            signature?.parameters["of"]?.type
                == .variable(name: "T", constraint: "Comparable")
        )
        #expect(
            signature?.parameters["value"]?.type
                == .variable(name: "T", constraint: "Comparable")
        )
        #expect(signature?.returns == .variable(name: "T", constraint: "Comparable"))
    }

    @Test("a bound in a slot is not a spelling, and a bound nobody mentions is refused")
    func aBoundBelongsToTheSignature() throws {
        // The slot names the parameter and nothing else — the constraint is
        // declared once, in the signature's `bounds`.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("some T: Comparable") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("some T:") }

        // A bound on a name no slot writes binds nothing.
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "bounds": ["T": "Comparable"],
                "parameters": ["of": "int"],
                "result": ["ref": "of"]
            ])
        }

        // A bound is a constraint's name, never a shape.
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "bounds": ["T": "array<int>"],
                "parameters": ["of": "some T"],
                "result": ["ref": "of"]
            ])
        }

        // A nested procedure type carries no bounds of its own — its
        // parameters are the declaring signature's slots, and the declaring
        // signature owns their bounds. Two records binding one namespace
        // would be two claims about one thing.
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "parameters": [
                    "by": [
                        "type": [
                            "procedure": [
                                "bounds": ["T": "Comparable"],
                                "parameters": ["item": "some T"],
                                "returns": "bool"
                            ]
                        ]
                    ]
                ],
                "result": ["ref": "by"]
            ])
        }
    }

    @Test("a bound reaches the parameters a nested signature mentions")
    func aBoundReachesNestedMentions() throws {
        // Given — `some Element` sits under array<…> and inside a procedure
        // type's own slot; both are this signature's mentions of one name
        let sut = try loader.loadProcedure([
            "bounds": ["Element": "Comparable"],
            "parameters": [
                "of": "array<some Element>",
                "by": [
                    "type": [
                        "procedure": [
                            "parameters": ["item": "some Element"],
                            "returns": "bool"
                        ]
                    ]
                ]
            ],
            "result": ["ref": "of"]
        ])

        // Then
        let parameters = sut.procedures[entryName]?.signature.parameters

        #expect(
            parameters?["of"]?.type
                == .array(.variable(name: "Element", constraint: "Comparable"))
        )

        guard case let .procedure(.some(inner), _) = parameters?["by"]?.type else {
            Issue.record("the procedure type did not survive reading")

            return
        }

        #expect(
            inner.parameters["item"]?.type
                == .variable(name: "Element", constraint: "Comparable")
        )
    }

    @Test("a name nothing builds in is a declared type")
    func unknownNameIsNamed() throws {
        #expect(try TypeReader.parse("Task") == .named("Task"))
    }

    @Test("an unbalanced argument is an author mistake, caught while reading")
    func unbalancedArgumentRejected() {
        #expect(throws: TypeFormError.self) { try TypeReader.parse("array<string") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("string>") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("string<int>") }
    }

    @Test("a module declares shapes its procedures name")
    func moduleDeclaresTypes() throws {
        // Given
        let sut = try loader.loadDocument([
            "types": ["Task": ["id": "string", "done": "bool"]],
            "procedures": [
                "entry": [
                    "parameters": ["tasks": "array<Task>"],
                    "body": [["id": "seen", "value": ["ref": "tasks"]]]
                ]
            ]
        ])

        // Then
        #expect(sut.types["Task"] == .record(["id": .string, "done": .bool]))
        #expect(
            sut.procedures["entry"]?.signature.parameters["tasks"]?.type
                == .array(.named("Task"))
        )
    }

    @Test("a declared shape is enforced at the call boundary")
    func declaredShapeIsEnforced() async throws {
        // Given
        let sut = try loader.loadDocument([
            "types": ["Task": ["id": "string"]],
            "procedures": [
                "entry": [
                    "parameters": ["tasks": "array<Task>"],
                    "body": [["id": "seen", "value": ["ref": "tasks"]]],
                    "result": ["result": ["ref": "seen"]]
                ]
            ]
        ])

        // When / Then
        let good = try await run(sut, arguments: ["tasks": .array([.object(["id": .string("a")])])])

        #expect(good["result"] == .array([.object(["id": .string("a")])]))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["tasks": .array([.object(["id": .int(1)])])])
        }
    }
}
