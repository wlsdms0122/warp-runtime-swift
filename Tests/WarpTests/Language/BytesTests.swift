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

// `bytes = array<byte>`. Bytes are not a special material, they are a compact
// spelling of an array of small whole numbers. The worth is the elements', the
// collection vocabulary applies, and only the spelling differs. `1` and `1.0`,
// one collection up.
@Suite
struct BytesTests {
    // MARK: - Property
    private let builder = Builder()
    private let entryName: Name = "entry"

    // MARK: - Test
    @Test("bytes and an array share their worth, not their spelling")
    func bytesAndArrayShareWorth() {
        let bytes = Value.bytes([104, 105])
        let ints = Value.array([.int(104), .int(105)])
        let fractions = Value.array([.double(104), .int(105)])

        // Worth unifies across spellings the way int and double do…
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
        // The slot asked for an array and bytes are one, so there is nothing to
        // do. Unpacking would spend an element per byte to answer nothing.
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

        // The one widening, per element: a byte where a fraction is declared.
        // The declaration changes every byte, so every byte is read out.
        #expect(
            try TypeExpression.array(.double).settling(.bytes([1]), at: "value")
                == .array([.double(1)])
        )

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
            "\(error)".contains("value[1]") && "\(error)".contains("outside int(0...200)")
        }
    }

    // `holdsEveryByte` says in one question what `settling` says one byte at a
    // time, and two statements of one rule drift apart silently. This is the
    // oracle that will not let them: for every shape below, the predicate's
    // answer is checked against what settling actually does to all 256 bytes,
    // so a shape added to one and forgotten by the other fails here.
    @Test("a byte settles as itself exactly where the type says it does")
    func aByteSettlesAsItselfExactlyWhereTheTypeSaysIt() throws {
        // `Named` is bound twice on purpose. Once as a type and once as a
        // constraint, which a table may do because they are two declarations. A
        // walk that guarded both with one set would end the constraint's
        // question by assuming the type's name and answer yes for `Textual`.
        let types = TypeTable(
            types: [
                "Small": .ranged(.whole(from: 0, to: .through(200))),
                "Whole": .int,
                "Named": .parameter(name: "Element", constraint: "Named")
            ],
            constraints: [
                "Ordered": [.int, .double, .string],
                "Textual": [.string],
                "Named": [.string],
                // Members that divide the range between them take every byte
                // even though no one of them takes it alone. A membership is
                // met when some member takes the value, and asking each member
                // to cover the whole range on its own would miss that.
                "Split": [.ranged(.whole(from: 0, to: .through(127))), .ranged(.whole(from: 128, to: .through(255)))],
                "Partial": [.ranged(.whole(from: 0, to: .through(127)))]
            ]
        )

        let loweredTypes: [TypeExpression] = [
            .any, .int, .number, .double, .string, .bool, .null, .never, .bytes,
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
            .parameter(name: "Element", constraint: "Ordered"),
            .parameter(name: "Element", constraint: "Textual"),
            .parameter(name: "Element", constraint: "Nobody"),
            .parameter(name: "Element", constraint: "Split"),
            .parameter(name: "Element", constraint: "Partial"),
            .named("Whole"),
            .named("Small"),
            .named("Nobody"),
            .named("Named"),
            .array(.int),
            .dictionary(.int),
            .record([:])
        ]

        for shape in loweredTypes {
            let untouched = (0...255).allSatisfy { byte in
                let value = Value.int(byte)

                return (try? shape.settling(value, at: "value", in: types)) == value
            }

            let table = types.loweredTypes

            #expect(
                shape.lowered(in: table).holdsEveryByte(in: table) == untouched,
                "\(shape.rendered) is held to say \(untouched)"
            )
        }
    }

    @Test("a bytes slot takes an array of byte worths, and settles it compactly")
    func aBytesSlotSettlesAnArray() throws {
        #expect(
            try TypeExpression.bytes.settling(.array([.int(104), .int(105)]), at: "value")
                == .bytes([104, 105])
        )

        // The element judge is byte's own, so the miss names the element.
        #expect {
            try TypeExpression.bytes.settling(.array([.int(104), .int(300)]), at: "value")
        } throws: { error in
            "\(error)".contains("value[1]") && "\(error)".contains("outside int(0...255)")
        }

        // A fraction is not a byte, whatever it is worth. The int edge again.
        #expect(throws: (any Error).self) {
            try TypeExpression.bytes.settling(.array([.double(1)]), at: "value")
        }
    }

    @Test("the equation is read at the build, by the elements")
    func acceptanceReadsTheElements() {
        #expect(TypeExpression.array(.int).accepts(.bytes))
        #expect(TypeExpression.array(.any).accepts(.bytes))
        #expect(TypeExpression.array(.double).accepts(.bytes))
        #expect(TypeExpression.bytes.accepts(.array(.ranged(.whole(from: 0, to: .through(255))))))
        #expect(TypeExpression.bytes.accepts(.array(.int)))
        #expect(!TypeExpression.array(.string).accepts(.bytes))
        #expect(!TypeExpression.bytes.accepts(.array(.string)))
        #expect(!TypeExpression.bytes.accepts(.array(.double)))
    }

    @Test("an index reads one byte out as the int it is")
    func anIndexReadsAByte() async throws {
        // Given. The path is judged at the build, drilled at the run
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["data": Parameter(type: .bytes)]
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

    @Test("the collection vocabulary applies to bytes directly")
    func collectionProceduresReadBytes() async throws {
        // Given. Each procedure declares an array receiver, and bytes are one
        let asks: [(Warp.Expression, Value)] = [
            (
                .call(Call(
                    receiver: reference("data"),
                    selector: "std.collection.count"
                )),
                .int(2)
            ),
            (
                .call(Call(
                    receiver: reference("data"),
                    selector: "std.collection.first"
                )),
                .int(104)
            ),
            (
                .call(Call(
                    receiver: reference("data"),
                    selector: "std.collection.reversed"
                )),
                // The receiver's own elements, in the other order, so the
                // spelling they arrived in is the spelling they leave in.
                .bytes([105, 104])
            ),
            (
                .call(Call(
                    receiver: reference("data"),
                    selector: "std.collection.contains",
                    arguments: ["value": .literal(.int(105))]
                )),
                .bool(true)
            )
        ]

        for (expression, answer) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        signature: Signature(
                            parameters: ["data": Parameter(type: .bytes)]
                        ),
                        body: [],
                        result: expression
                    )
                ]
            )

            // When / Then
            #expect(try await run(sut, arguments: ["data": .bytes([104, 105])]) == answer)
        }
    }

    @Test("a procedure wanting elements no byte can be refuses at the boundary, by the element")
    func aProcedureWantingOtherElementsRefusesAtTheBoundary() async throws {
        // Given. `joined` declares `array<string>`, which leaves no byte as it
        // is, so the compact spelling does not cross: it is read out and
        // settled element by element. The receiver is read `any` here so the
        // link lets it through and the run is the one that answers.
        //
        // This is why a procedure whose elements no byte can be still asks for the
        // `.array` case: a bytes value never reaches it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["data": Parameter(type: .any)]
                    ),
                    body: [],
                    result: .call(Call(
                        receiver: reference("data"),
                        selector: "std.text.joined"
                    ))
                )
            ]
        )

        // When / Then. The refusal names the element that disagreed, never that
        // bytes are not an array.
        await #expect {
            try await run(sut, arguments: ["data": .bytes([104, 105])])
        } throws: { error in
            "\(error)".contains("'of'[0]: expected string, got int")
                && !"\(error)".contains("expected array")
        }
    }

    @Test("a walk over bytes reads the ordinary int each byte is")
    func aWalkOverBytesReadsInts() async throws {
        // Given. Bytes count and index the way an array does, so the loop that
        // walks one reads each byte as the ordinary int it is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["data": Parameter(type: .bytes)]
                    ),
                    body: [
                        Statement(binding: .variable("sum"), expression: .literal(.int(0))
                        ),
                        Statement(
                            binding: .constant("walk"),
                            expression: walking(
                                [.key("data")],
                                element: "element",
                                body: [
                                    Statement(binding: .assignment([.key("sum")]), expression: .call(Call(
                                            receiver: reference("sum"),
                                            selector: "std.math.plus",
                                            arguments: ["value": reference("element")]
                                        ))
                                    )
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

    @Test("decoded and encoded are two directions of one named mapping")
    func decodedAndEncodedRoundTrip() async throws {
        // Given
        func procedure(_ selector: Name, on receiver: Value) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .call(Call(
                            receiver: .literal(receiver),
                            selector: selector
                        ))
                    )
                ]
            )
        }

        // When / Then
        #expect(try await run(procedure("std.text.decoded", on: .bytes([104, 105]))) == .string("hi"))
        #expect(try await run(procedure("std.text.encoded", on: .string("hi"))) == .bytes([104, 105]))

        // Bytes carry no promise of being text, and a completed guess is a
        // text nobody sent.
        await #expect {
            try await run(procedure("std.text.decoded", on: .bytes([0xff])))
        } throws: { error in
            "\(error)".contains("not utf8 text")
        }
    }

    @Test("an encoding the procedures do not name refuses at the build")
    func anUnknownEncodingRefuses() throws {
        // Given. The enum names the encodings, and a constant is judged at the
        // link
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.bytes([104])),
                        selector: "std.text.decoded",
                        arguments: ["encoding": .literal(.string("utf16"))]
                    ))
                )
            ]
        )

        // When / Then
        #expect(throws: BuildError.self) {
            try builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a mixed literal joins by the equation, not to any")
    func aMixedLiteralJoinsByTheEquation() async throws {
        // Given. The elements spell one type two ways, so the list's element
        // type is that type and the call is judged, not waved through as any
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .array(.array(.int)))],
                        returns: .array(.array(.int))
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    body: [],
                    result: .call(Call(
                        selector: "keep",
                        arguments: [
                            "value": .literal(.array([
                                .bytes([104, 105]),
                                .array([.int(1), .int(2)])
                            ]))
                        ]
                    ))
                )
            ]
        )

        // When / Then. The element declaration `array<int>` asks nothing of a
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
        // `text` spells a value the way a document writes it, and a document
        // writes bytes `x"6869"`. The bare digits this once showed are a form
        // nothing reads back.
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
                        parameters: ["value": Parameter(type: .array(.int))],
                        returns: .array(.int)
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    body: [],
                    result: .call(Call(
                        selector: "keep",
                        arguments: ["value": .literal(.bytes([104, 105]))]
                    ))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .bytes([104, 105]))
    }
}
