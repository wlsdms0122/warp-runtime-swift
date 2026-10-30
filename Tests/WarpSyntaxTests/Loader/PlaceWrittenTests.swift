//
//  PlaceWrittenTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/1/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard
import WarpTestSupport

// A refusal about a document, addressed in the document's own keys and
// positions, the place `CHECKING.md` names.
//
// The language names its parts for itself, which is the right choice for a
// caller that assembled a program in Swift and wrote no document. Here there
// is a document: `condition` is a part no document writes, and `while` is what
// it writes.
@Suite("A place reads in the keys the document writes")
struct PlaceWrittenTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a refusal from the checking is addressed in the document's keys")
    func aCheckingRefusalIsSpelledForTheAuthor() throws {
        // Given. A loop whose condition reads a name nothing declares. The
        // language calls that part a condition and a loop writes it `while`,
        // inside the statement's `value`.
        let document = Self.document(body: [
            [
                "let": "spin",
                "value": ["loop": [
                    "while": ["ref": "missing"],
                    "body": []
                ]
            ]]
        ])
        let identity = try Identity.of(document)

        // When
        let error = #expect(throws: ValidationError.self) {
            try loader.load(document)
        }

        // Then
        let steps: Value = ["procedures", "entry", "body", 0, "value", "loop", "while"]

        #expect(error?.place?.value == [.bytes(identity.bytes), steps])
    }

    @Test("a conditional and a loop hold one part and write two keys")
    func oneSlotIsWrittenTwoWays() {
        // Given. The language calls both a condition, so the key a place reads
        // with is decided by the construct the walk is inside.
        let conditional = Place.procedure(entryName.spelling, in: .assembled)
            .part(.body)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .part(.condition(of: .conditional))

        let loop = Place.procedure(entryName.spelling, in: .assembled)
            .part(.body)
            .statement("spin", at: 0)
            .appending(.construct(.loop))
            .part(.condition(of: .loop))

        // When / Then
        #expect(conditional.written().rendered == "procedures.entry.body[0].value.conditional.when")
        #expect(loop.written().rendered == "procedures.entry.body[0].value.loop.while")

        // And the language's own reading says one thing for both
        #expect(conditional.rendered == "procedures.entry.body.pick[0].conditional.condition")
        #expect(loop.rendered == "procedures.entry.body.spin[0].loop.condition")
    }

    @Test("a link refusal reads in the document's keys")
    func aLinkRefusalIsSpelledForTheAuthor() async throws {
        // Given. The stage that has no document of its own. What to link is the
        // host's statement, so a link cannot know which text a module came
        // out of; the side that read the text can say.
        let document = Self.document(body: [
            [
                "let": "sent",
                "value": ["call": ["procedure": "nowhere", "arguments": [1]]
            ]]
        ], importing: ["nowhere"])
        let identity = try Identity.of(document)
        let module = try loader.load(document)

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([module])
        }

        // Then. The call is the statement's `value`, at the statement's
        // position in the body
        #expect(error?.place?.value == [.bytes(identity.bytes), ["procedures", "entry", "body", 0, "value"]])

        // And in its own sentence the language speaks in its own terms
        #expect(error?.place?.rendered == "\(identity.short)/procedures.entry.body.sent[0].call")
    }

    @Test("a build refusal steps through the keys and positions the document writes")
    func aBuildRefusalWalksTheDocument() async throws {
        // Given. A call written with one argument too many, itself an
        // argument of a call returned in a conditional's arm. Each call writes
        // its arguments under its own `call`, the inner one included, and each
        // statement is a position
        let plus: Value = "Standard.Numeric.plus"
        let document: Value = [
            "warp": 1,
            "imports": [plus],
            "procedures": ["entry": [
                "access": "public",
                "returns": "Int",
                "body": [
                    ["value": ["conditional": [
                        "when": true,
                        "then": [["value": ["return": ["call": [
                            "procedure": plus,
                            "arguments": [1, ["call": ["procedure": plus, "arguments": [1, 2, 3]]]]
                        ]]]]]
                    ]]],
                    ["value": ["return": 0]]
                ]
            ]]
        ]
        let identity = try Identity.of(document)
        let module = try loader.load(document)

        // When
        let error = await #expect(throws: (any Error).self) {
            try await Builder().build([module] + Module.standard)
        }

        // Then
        let steps: Value = [
            "procedures", "entry", "body", 0, "value", "conditional", "then", 0,
            "value", "return", "call", "arguments", 1, "call", "arguments"
        ]

        #expect((error as? any WarpError)?.place?.value == [.bytes(identity.bytes), steps])
    }

    @Test(
        "a load refusal inside a procedure type names the parameter that writes it",
        arguments: ["(Self) -> Int", "() -> Self"]
    )
    func aLoadRefusalInsideAProcedureTypeStopsAtItsSlot(type: String) throws {
        // Given. `Self` stands only in a contract's procedures, written here
        // inside the type of a parameter. The type is one string, so no step
        // leads into it
        let document = Self.document(declaring: type)
        let identity = try Identity.of(document)

        // When
        let error = #expect(throws: ValidationError.self) {
            try loader.load(document)
        }

        // Then
        #expect(error?.place?.value == [.bytes(identity.bytes), ["procedures", "entry", "parameters", 0]])
    }

    @Test(
        "a build refusal inside a procedure type names the parameter that writes it",
        arguments: ["(App.Missing) -> Int", "() -> App.Missing"]
    )
    func aBuildRefusalInsideAProcedureTypeStopsAtItsSlot(type: String) async throws {
        // Given. A name nothing declares, written inside the type of a
        // parameter
        let document = Self.document(declaring: type, importing: ["App.Missing"])
        let identity = try Identity.of(document)
        let module = try loader.load(document)

        // When
        let error = await #expect(throws: BuildError.self) {
            try await Builder().build([module] + Module.standard)
        }

        // Then
        #expect(error?.place?.value == [.bytes(identity.bytes), ["procedures", "entry", "parameters", 0]])
    }

    @Test("a run's refusal says where the run was and names no place")
    func aRunRefusalIsNoPlace() async throws {
        // Given. A run refuses where it stands, which a trace says. A place is
        // what the load and the build name, so a run's refusal names none
        let document: Value = [
            "warp": 1,
            "imports": ["Standard.Numeric.dividedBy"],
            "procedures": ["entry": [
                "access": "public",
                "returns": "Double",
                "body": [["value": ["return": ["call": ["procedure": "Standard.Numeric.dividedBy", "arguments": [1, 0]]]]]]
            ]]
        ]
        let module = try loader.load(document)
        let image = try await Builder().build([module] + Module.standard)

        // When
        let error = await #expect(throws: (any Error).self) {
            try await Executor().run(image, entry: entryName)
        }

        // Then
        let refusal = error as? any WarpError

        #expect(refusal?.trace != nil)
        #expect(refusal?.place == nil)
    }

    @Test("a place is the value of the document's identity and its steps")
    func aPlaceIsAValue() throws {
        // Given. `CHECKING.md` carries a place as `[identity, steps]`: the
        // identity as its bytes and each step a string key or an int position
        let identity = Identity(Array(repeating: 0xcd, count: 32))
        let document = Place.Document(identity: identity)
        let place = Place(
            [.part(.procedures), .key("App.g")],
            in: document
        )
        .part(.body)
        .statement("sum", at: 2)
        .appending(.construct(.call))
        .child(.argument(0))
        .written()

        // When
        let value = try #require(place.value)

        // Then
        #expect(
            value == [
                .bytes(identity.bytes),
                ["procedures", "App.g", "body", 2, "value", "call", "arguments", 0]
            ]
        )

        // And it crosses in the bytes as any value does
        #expect(try BinaryEncoding().value(from: try BinaryEncoding().data(from: value)) == value)
    }

    @Test("a place that is no spot in a document has no value")
    func anAssembledPlaceHasNoValue() {
        // Given. A program never written down has no identity, and a body a
        // host assembled is no spot a document writes
        let identity = Identity(Array(repeating: 0xcd, count: 32))
        let assembled = Place.given("entry").written()
        let landmarked = Place([.part(.procedures), .landmark("entry")], in: Place.Document(identity: identity))
        let unnamed = Place([.key("procedures"), .key("entry")], in: .assembled)

        // When / Then
        #expect(assembled.value == nil)
        #expect(landmarked.value == nil)
        #expect(assembled.steps == [.landmark("entry")])
        #expect(unnamed.value == nil)
    }

    // MARK: - Public
    // MARK: - Private
    // A document declaring `entry` with one parameter of this type, whole, so
    // it has an identity a place can name.
    private static func document(declaring type: String, importing imports: [Value] = []) -> Value {
        [
            "warp": 1,
            "imports": .array(imports),
            "procedures": ["entry": [
                "access": "public",
                "parameters": [["name": "given", "type": .string(type)]]
            ]]
        ]
    }

    // A document declaring `entry` with this body, whole, so it has an
    // identity a place can name.
    private static func document(body: Value, importing imports: [Value] = []) -> Value {
        [
            "warp": 1,
            "imports": .array(imports),
            "procedures": ["entry": ["access": "public", "body": body]]
        ]
    }
}
