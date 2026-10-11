//
//  BytesTests.swift
//  WarpTests
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// Bytes are `Array<Int>` in a compact spelling, each element from 0 to 255.
// The worth is the elements', the collection vocabulary applies, and only the
// spelling differs, as between `1` and `1.0`.
@Suite("Bytes")
struct BytesTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("bytes and an array share their worth, not their spelling")
    func bytesAndArrayShareWorth() {
        // Given
        let bytes = Value.bytes([104, 105])
        let ints = Value.array([.int(104), .int(105)])
        let fractions = Value.array([.double(104), .int(105)])

        // When / Then. Worth unifies across spellings the way int and double
        // do…
        #expect(bytes.matches(ints))
        #expect(bytes.matches(fractions))
        #expect(!bytes.matches(.array([.int(104)])))
        #expect(!bytes.matches(.array([.int(104), .int(106)])))

        // …and the spellings stay two values, the way 1 and 1.0 do.
        #expect(bytes != ints)
        #expect(Value.order(bytes, ints) == nil)
    }

    @Test("an array slot that asks nothing of a byte takes the compact spelling whole")
    func anArraySlotSettlesBytes() throws {
        // When / Then. The slot asked for an array and bytes are one, so there
        // is nothing to do. Unpacking would spend an element per byte to answer
        // nothing.
        #expect(
            try TypeExpression.array(.int).settling(.bytes([104, 105]), at: "value")
                == .bytes([104, 105])
        )
        #expect(
            try TypeExpression.array(.any).settling(.bytes([104, 105]), at: "value")
                == .bytes([104, 105])
        )

        // A byte is a whole number, so a list of fractions takes none.
        #expect(throws: (any Error).self) {
            try TypeExpression.array(.double).settling(.bytes([1]), at: "value")
        }
    }

    // `holdsEveryByte` answers in one question what `settling` answers one byte
    // at a time. For every type below, the predicate's answer is checked
    // against what settling does to all 256 bytes.
    @Test("a byte settles as itself exactly where the type says it does")
    func aByteSettlesAsItselfExactlyWhereTheTypeSaysIt() throws {
        // Given. Every claim is in, so a bound is answered by what the
        // claims say of `Int`, which is what every byte is.
        let types = TypeTable(
            types: [
                "Whole": .int
            ],
            contracts: ["Ordered": [:], "Textual": [:]],
            satisfying: ["Ordered": ["Int", "Double", "String"], "Textual": ["String"]],
            holdsEveryClaim: true,
            of: Linkage()
        )

        let unbounded: [TypeExpression] = [
            .any, .int, .double, .string, .bool, .null, .never,
            .nullable(.int),
            .parameter(name: "Element"),
            .named("Whole"),
            .named("Nobody"),
            .array(.int),
            .dictionary(.int),
            .record([:])
        ]
        let bounded: [(TypeExpression, [Name: Set<Name>])] = [
            (.parameter(name: "Element"), ["Element": ["Ordered"]]),
            (.parameter(name: "Element"), ["Element": ["Textual"]]),
            (.parameter(name: "Element"), ["Element": ["Nobody"]])
        ]
        let table = types.loweredTypes

        // When / Then
        for (type, bounds) in unbounded.map({ type in (type, [:]) }) + bounded {
            let lowered = type.lowered(in: table, bounds: bounds)
            let untouched = (0...255).allSatisfy { byte in
                let value = Value.int(byte)

                return (try? lowered.settling(outside: value, at: "value", in: table)) == value
            }

            #expect(
                lowered.holdsEveryByte(in: table) == untouched,
                "\(lowered.rendered(in: table)) is held to say \(untouched)"
            )
        }
    }

    @Test("a value answers its bytes in either spelling")
    func bytesAreReadFromEitherSpelling() {
        // When / Then
        #expect(Value.bytes([104, 105]).bytes == [104, 105])
        #expect(Value.array([.int(104), .int(105)]).bytes == [104, 105])
        #expect(Value.array([]).bytes == [])
        #expect(Value.array([.int(104), .int(300)]).bytes == nil)
        #expect(Value.array([.double(1)]).bytes == nil)
        #expect(Value.string("hi").bytes == nil)
    }

    @Test("an index reads one byte out as the Int it is")
    func anIndexReadsAByte() async throws {
        // Given. The path is judged at the build, drilled at the run
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "data", type: .array(.int))]
                    ),
                    body: [],
                    result: .reference([.key("data"), .index(1)])
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["data": .bytes([104, 105])]) == .int(105))

        await #expect {
            try await run(sut, arguments: ["data": .bytes([104])])
        } throws: { error in
            "\(error)".contains("past the end")
        }
    }

    @Test("the entry door refuses bytes where elements no byte can be are declared, by the element")
    func theEntryRefusesBytesByTheElement() async throws {
        // Given. The entry takes `Array<String>`, which leaves no byte as it
        // is, so the bytes handed in are judged element by element at the
        // door the arguments come through
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "data", type: .array(.string))]
                    ),
                    body: [],
                    result: .call(Call(selector: "Standard.Text.joined", arguments: [reference("data"), .literal(.string(""))]))
                )
            ]
        )

        // When / Then. The refusal names the element that disagreed, never that
        // bytes are not an array.
        await #expect {
            try await run(sut, arguments: ["data": .bytes([104, 105])])
        } throws: { error in
            "\(error)".contains("input 'data'[0]: expected String, got Int")
                && !"\(error)".contains("expected Array,")
        }
    }

    @Test("a walk over bytes reads the ordinary Int each byte is")
    func aWalkOverBytesReadsInts() async throws {
        // Given. Bytes count and index the way an array does, so the loop that
        // walks one reads each byte as the ordinary Int it is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "data", type: .array(.int))]
                    ),
                    body: [
                        Statement(binding: .variable("sum"), expression: .literal(.int(0))),
                        Statement(
                            binding: .constant("walk"),
                            expression: walking(
                                [.key("data")],
                                element: "element",
                                body: [
                                    Statement(binding: .assignment([.key("sum")]), expression: .call(Call(
                                        selector: "Standard.Numeric.plus",
                                        arguments: [reference("sum"), reference("element")]
                                    )))
                                ]
                            )
                        )
                    ],
                    result: reference("sum")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["data": .bytes([104, 105])]) == .int(209))
    }

    @Test("a mixed literal joins as the list of whole numbers both spellings are, not to any")
    func aMixedLiteralJoinsAsOneList() async throws {
        // Given. The elements spell one type two ways, so the list's element
        // type is that type and the call is judged, not waved through as any
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .array(.array(.int)))],
                        returns: .array(.array(.int))
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "keep",
                        arguments: [
                            .literal(.array([
                                .bytes([104, 105]),
                                .array([.int(1), .int(2)])
                            ]))
                        ]
                    ))
                )
            ]
        )

        // When / Then. The element declaration `Array<Int>` asks nothing of a
        // byte, so the compact member crosses as itself and the long one as
        // itself: each value keeps the spelling it was written in.
        #expect(
            try await run(sut)
                == .array([
                    .bytes([104, 105]),
                    .array([.int(1), .int(2)])
                ])
        )
    }

    @Test("text spells bytes the way a document writes them, at every depth")
    func renderingSpellsBytesAsTheDocumentDoes() {
        // When / Then. `text` spells a value the way a document writes it, and
        // a document writes bytes `x"6869"`.
        #expect(Rendering(.bytes([104, 105])).text() == "x\"6869\"")

        // The same spelling however deep it sits. The quotes are the
        // position's, exactly as they are for a string.
        #expect(Rendering(.array([.bytes([104, 105])])).text() == "[\"x\\\"6869\\\"\"]")
        #expect(Rendering(.array([.string("hi")])).text() == "[\"hi\"]")
    }

    @Test("what JSON cannot say shows as unencodable, never as almost-JSON")
    func renderingHoldsTheFiniteLine() {
        // Given. Infinity arrives only from a host's own procedure, and the
        // rendering must not leak it as invalid JSON

        // When / Then
        #expect(Rendering(.array([.double(.infinity)])).text() == "<unencodable>")
        #expect(Rendering(.dictionary(["a": .double(.nan)])).text() == "<unencodable>")
        #expect(Rendering(.array([.double(1.5), .int(1)])).text() == "[1.5,1]")

        // The rendering writes the document's spelling, not the host's. The
        // same fraction must come back readable as the document it names.
        #expect(
            Rendering(.array([.double(9_109_348_289_431_844.0)])).text()
                == "[9109348289431844.0]"
        )
    }

    @Test("a bytes literal fills an array slot at the build, and crosses it whole")
    func aBytesConstantFillsAnArraySlot() async throws {
        // Given. Bytes are a list of whole numbers at the build, and the
        // boundary has nothing to settle: the slot asked for an array and
        // bytes are one
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .array(.int))],
                        returns: .array(.int)
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [.literal(.bytes([104, 105]))]))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .bytes([104, 105]))
    }

    // MARK: - Public
    // MARK: - Private
}
