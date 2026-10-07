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

// `bytes = Array<byte>`. Bytes are not a special material, they are a compact
// spelling of an array of small whole numbers. The worth is the elements', the
// collection vocabulary applies, and only the spelling differs. `1` and `1.0`,
// one collection up.
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
        #expect(
            try TypeExpression.array(.ranged(.whole(to: .through(255))))
                .settling(.bytes([104, 105]), at: "value") == .bytes([104, 105])
        )

        // A byte is a whole number, so a list of fractions takes none.
        #expect(throws: (any Error).self) {
            try TypeExpression.array(.double).settling(.bytes([1]), at: "value")
        }

        // A range narrower than `byte` has something to ask of each one, and
        // the refusal names which byte and by how much.
        #expect(
            try TypeExpression.array(.ranged(.whole(from: 0, to: .through(200))))
                .settling(.bytes([1, 2]), at: "value") == .array([.int(1), .int(2)])
        )

        #expect {
            try TypeExpression.array(.ranged(.whole(from: 0, to: .through(200))))
                .settling(.bytes([1, 255]), at: "value")
        } throws: { error in
            "\(error)".contains("value[1]") && "\(error)".contains("outside Int(0...200)")
        }
    }

    // `holdsEveryByte` says in one question what `settling` says one byte at a
    // time, and two statements of one rule drift apart silently. This is the
    // oracle that will not let them: for every type below, the predicate's
    // answer is checked against what settling actually does to all 256 bytes,
    // so a type added to one and forgotten by the other fails here.
    @Test("a byte settles as itself exactly where the type says it does")
    func aByteSettlesAsItselfExactlyWhereTheTypeSaysIt() throws {
        // Given. Every claim is in, so a bound is answered by what the
        // claims say of `Int`, which is what every byte is.
        let types = TypeTable(
            types: [
                "Small": .ranged(.whole(from: 0, to: .through(200))),
                "Whole": .int
            ],
            contracts: ["Ordered": [:], "Textual": [:]],
            satisfying: ["Ordered": ["Int", "Double", "String"], "Textual": ["String"]],
            settled: true,
            of: Linkage()
        )

        let typeExpressions: [TypeExpression] = [
            .any, .int, .double, .string, .bool, .null, .never,
            .ranged(.whole(from: 0, to: .through(255))),
            .ranged(.whole()),
            .ranged(.whole(from: 0, to: .through(254))),
            .ranged(.whole(from: 1, to: .through(255))),
            .ranged(.whole(from: 0, to: .upTo(256))),
            .ranged(.whole(from: 0, to: .upTo(255))),
            .ranged(.fraction(from: 0, to: .through(255))),
            .ranged(.fraction()),
            .nullable(.int),
            .nullable(.ranged(.whole(from: 0, to: .through(254)))),
            .parameter(name: "Element"),
            .parameter(name: "Element", bounds: ["Ordered"]),
            .parameter(name: "Element", bounds: ["Textual"]),
            .parameter(name: "Element", bounds: ["Nobody"]),
            .named("Whole"),
            .named("Small"),
            .named("Nobody"),
            .array(.int),
            .dictionary(.int),
            .record([:])
        ]

        // When / Then
        for type in typeExpressions {
            let untouched = (0...255).allSatisfy { byte in
                let value = Value.int(byte)

                return (try? type.settling(value, at: "value", in: types)) == value
            }

            let table = types.loweredTypes

            #expect(
                type.lowered(in: table).holdsEveryByte(in: table) == untouched,
                "\(type.rendered) is held to say \(untouched)"
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

    @Test("the equation is read at the build, by the elements")
    func acceptanceReadsTheElements() {
        // When / Then
        #expect(TypeExpression.array(.int).accepts(.array(.byteElement)))
        #expect(TypeExpression.array(.any).accepts(.array(.byteElement)))
        #expect(!TypeExpression.array(.double).accepts(.array(.byteElement)))
        #expect(TypeExpression.array(.byteElement).accepts(.array(.int)))
        #expect(!TypeExpression.array(.string).accepts(.array(.byteElement)))
        #expect(!TypeExpression.array(.byteElement).accepts(.array(.string)))
        #expect(!TypeExpression.array(.byteElement).accepts(.array(.double)))
    }

    @Test("an index reads one byte out as the Int it is")
    func anIndexReadsAByte() async throws {
        // Given. The path is judged at the build, drilled at the run
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "data", type: .bytes)]
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

    @Test("a procedure wanting elements no byte can be refuses at the boundary, by the element")
    func aProcedureWantingOtherElementsRefusesAtTheBoundary() async throws {
        // Given. `joined` declares `Array<String>`, which leaves no byte as it
        // is, so the compact spelling does not cross: it is read out and
        // settled element by element. The argument is read `Any` here so the
        // build lets it through and the run is the one that answers.
        //
        // This is why a procedure whose elements no byte can be still asks for the
        // `.array` case: a bytes value never reaches it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "data", type: .any)]
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
            "\(error)".contains("input 'strings'[0]: expected String, got Int")
                && !"\(error)".contains("expected array")
        }
    }

    @Test("a walk over bytes reads the ordinary Int each byte is")
    func aWalkOverBytesReadsInts() async throws {
        // Given. Bytes count and index the way an array does, so the loop that
        // walks one reads each byte as the ordinary int it is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "data", type: .bytes)]
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

    @Test("a mixed literal joins by the equation, not to any")
    func aMixedLiteralJoinsByTheEquation() async throws {
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

        // The document writer is one recursive function and writes the same
        // spelling however deep it sits, so this does too. The quotes are the
        // position's, exactly as they are for a string.
        #expect(Rendering(.array([.bytes([104, 105])])).text() == "[\"x\\\"6869\\\"\"]")
        #expect(Rendering(.array([.string("hi")])).text() == "[\"hi\"]")

        // What the Codable projection writes is the array the equation says
        // bytes are. A different answer for a different question, held by
        // `bytesAreWrittenAsTheArrayTheyAre` over in the document tests. That
        // one is read back; this one is read by a person.
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
        // Given. The equation is read at the build, and the boundary has nothing
        // to settle: the slot asked for an array and bytes are one
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
