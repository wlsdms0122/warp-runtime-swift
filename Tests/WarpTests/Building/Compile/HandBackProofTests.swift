//
//  HandBackProofTests.swift
//  WarpTests
//
//  Created by JSilver on 10/3/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// Whether a body answers as its declaration says is settled over the whole
// document, the way its constness is: a body proves it alone or leans on
// the declarations it calls, and which it leans on is read once every body
// is read, whatever order they were read in.
@Suite("What a body proves of what it hands back")
struct HandBackProofTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body answering what a declaration read after it answers is proven with it")
    func aBodyLeaningOnALaterOneIsProven() async throws {
        // Given. `App.a` is read before `App.z`, and answers what it answers
        let sut = try Module(
            procedures: [
                "App.a": generic(result: .call(Call(selector: "App.z", arguments: [.reference([.key("x")])]))),
                "App.z": generic(result: .reference([.key("x")]))
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.a"]?.handsBackAsDeclared == true)
        #expect(image["App.z"]?.handsBackAsDeclared == true)
    }

    @Test("a body answering what an unproven one answers is not proven")
    func aBodyLeaningOnAnUnprovenOneIsNot() async throws {
        // Given. `App.z` answers what calling a value answers
        let sut = try Module(
            procedures: [
                "App.a": generic(result: .call(Call(selector: "App.z", arguments: [.reference([.key("x")])]))),
                "App.z": unproven()
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.z"]?.handsBackAsDeclared == false)
        #expect(image["App.a"]?.handsBackAsDeclared == false)
    }

    @Test("a body leaning on itself keeps what nothing else took away")
    func aRecursiveBodyIsProven() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "App.r": generic(result: .call(Call(selector: "App.r", arguments: [.reference([.key("x")])])))
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.r"]?.handsBackAsDeclared == true)
    }

    @Test("two bodies leaning on each other keep what nothing else took away")
    func twoBodiesLeaningOnEachOtherAreProven() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "App.a": generic(result: .call(Call(selector: "App.b", arguments: [.reference([.key("x")])]))),
                "App.b": generic(result: .call(Call(selector: "App.a", arguments: [.reference([.key("x")])])))
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.a"]?.handsBackAsDeclared == true)
        #expect(image["App.b"]?.handsBackAsDeclared == true)
    }

    @Test("a cycle leaning on an unproven body falls whole")
    func aCycleLeaningOnAnUnprovenOneFalls() async throws {
        // Given. `App.a` and `App.b` lean on each other, and `App.b` also on `App.c`, the only one answering what calling a value answers
        let sut = try Module(
            procedures: [
                "App.a": generic(result: .call(Call(selector: "App.b", arguments: [.reference([.key("x")])]))),
                "App.b": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                        returns: .parameter(name: "T")
                    ),
                    body: [
                        Statement(
                            binding: .constant("back"),
                            expression: .call(Call(selector: "App.a", arguments: [.reference([.key("x")])]))
                        )
                    ],
                    result: .call(Call(selector: "App.c", arguments: [.reference([.key("x")])]))
                ),
                "App.c": unproven()
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.c"]?.handsBackAsDeclared == false)
        #expect(image["App.b"]?.handsBackAsDeclared == false)
        #expect(image["App.a"]?.handsBackAsDeclared == false)
    }

    @Test("a fall carries back along the bodies leaning on it")
    func aFallCarriesBackAlongTheChain() async throws {
        // Given. `App.a` leans on `App.b`, `App.b` on `App.c`, and only `App.c` answers what calling a value answers
        let sut = try Module(
            procedures: [
                "App.a": generic(result: .call(Call(selector: "App.b", arguments: [.reference([.key("x")])]))),
                "App.b": generic(result: .call(Call(selector: "App.c", arguments: [.reference([.key("x")])]))),
                "App.c": unproven()
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then. `App.a` falls only once `App.b` has
        #expect(image["App.c"]?.handsBackAsDeclared == false)
        #expect(image["App.b"]?.handsBackAsDeclared == false)
        #expect(image["App.a"]?.handsBackAsDeclared == false)
    }

    @Test("a body that wrote no answer proves what was read off it")
    func anUnsaidBodyProvesWhatWasReadOffIt() async throws {
        // Given. `App.g` writes no `returns`, and what was read off it is its `some T`, carried from `App.f`, which answers what calling a value answers
        let sut = try Module(
            procedures: [
                "App.f": unproven(),
                "App.g": Procedure(
                    signature: Signature(parameters: [Parameter(name: "x", type: .parameter(name: "T"))]),
                    body: [],
                    result: .call(Call(selector: "App.f", arguments: [.reference([.key("x")])]))
                ),
                "App.h": Procedure(
                    signature: Signature(parameters: [Parameter(name: "x", type: .parameter(name: "T"))]),
                    body: [],
                    result: .reference([.key("x")])
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.g"]?.handsBackAsDeclared == false)
        #expect(image["App.h"]?.handsBackAsDeclared == true)
    }

    @Test("a body handed a variable in place at a type parameter proves what it writes there")
    func aBodyHandedAVariableInPlaceProvesWhatItWrites() async throws {
        // Given. `App.put` answers a whole number, and writes what `App.f` answers into the list it was handed in place
        let sut = try Module(
            imports: ["Standard.Collection.append"],
            procedures: [
                "App.f": unproven(),
                "App.put": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "x", type: .parameter(name: "T")),
                            Parameter(name: "xs", type: .inout(.array(.parameter(name: "T"))))
                        ],
                        returns: .int
                    ),
                    body: [
                        Statement(
                            binding: .constant("got"),
                            expression: .call(Call(selector: "App.f", arguments: [.reference([.key("x")])]))
                        ),
                        Statement(
                            expression: .call(Call(selector: "Standard.Collection.append", arguments: [.reference([.key("xs")]), .reference([.key("got")])]))
                        )
                    ],
                    result: .literal(.int(0))
                ),
                "App.keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "x", type: .parameter(name: "T")),
                            Parameter(name: "xs", type: .inout(.array(.parameter(name: "T"))))
                        ],
                        returns: .int
                    ),
                    body: [
                        Statement(
                            expression: .call(Call(selector: "Standard.Collection.append", arguments: [.reference([.key("xs")]), .reference([.key("x")])]))
                        )
                    ],
                    result: .literal(.int(0))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.put"]?.handsBackAsDeclared == false)
        #expect(image["App.keep"]?.handsBackAsDeclared == true)
    }

    @Test("a body filling a call's type parameter from its own beside what is not a value of it refuses, and one handing its own twice is proven")
    func aBodyFillingAParameterBesideAnotherValueRefuses() async throws {
        // Given. `App.mixed` hands `App.pick` a list of its `some T` and a list read as `Array<Any>`, `App.same` hands it its own twice
        let pick = Procedure(
            signature: Signature(
                parameters: [
                    Parameter(name: "a", type: .parameter(name: "E")),
                    Parameter(name: "b", type: .parameter(name: "E"))
                ],
                returns: .parameter(name: "E")
            ),
            body: [],
            result: .reference([.key("b")])
        )
        let mixed = try Module(
            procedures: [
                "App.pick": pick,
                "App.mixed": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "x", type: .parameter(name: "T")),
                            Parameter(name: "junk", type: .array(.any))
                        ],
                        returns: .array(.parameter(name: "T"))
                    ),
                    body: [],
                    result: .call(Call(selector: "App.pick", arguments: [.array([.reference([.key("x")])]), .reference([.key("junk")])]))
                )
            ]
        )
        let same = try Module(
            procedures: [
                "App.pick": pick,
                "App.same": generic(result: .call(Call(selector: "App.pick", arguments: [.reference([.key("x")]), .reference([.key("x")])])))
            ]
        )

        // When
        let image = try await Builder().build([same] + Module.standard)

        // Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([mixed] + Module.standard)
        }
        #expect(image["App.pick"]?.handsBackAsDeclared == true)
        #expect(image["App.same"]?.handsBackAsDeclared == true)
    }

    @Test("a body whose closure may write a variable of its type parameter proves nothing, and one whose closure only reads a parameter does")
    func aBodyWhoseClosureWritesAVariableOfItsParameterIsNotProven() async throws {
        // Given. Both closures write a variable the body declared, so neither is isolated. `App.writes` has its closure write `cell`, a variable of `some T`; `App.reads` has its closure write a whole number and read `x`
        let sut = try Module(
            procedures: [
                "App.writes": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                        returns: .parameter(name: "T")
                    ),
                    body: [
                        Statement(binding: .variable("cell"), expression: .reference([.key("x")])),
                        Statement(binding: .constant("c"), expression: closure(writing: "cell", with: .reference([.key("x")]))),
                        Statement(binding: .constant("z"), expression: .apply(.reference([.key("c")]), arguments: []))
                    ],
                    result: .reference([.key("cell")])
                ),
                "App.reads": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                        returns: .parameter(name: "T")
                    ),
                    body: [
                        Statement(binding: .variable("count"), expression: .literal(.int(0))),
                        Statement(
                            binding: .constant("c"),
                            expression: closure(writing: "count", with: .literal(.int(1)), reading: .reference([.key("x")]))
                        ),
                        Statement(binding: .constant("z"), expression: .apply(.reference([.key("c")]), arguments: []))
                    ],
                    result: .reference([.key("x")])
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.writes"]?.handsBackAsDeclared == false)
        #expect(image["App.reads"]?.handsBackAsDeclared == true)
    }

    // MARK: - Public
    // MARK: - Private
    // A closure answering a whole number that writes a value into a name it
    // captured, and reads another value where one is given.
    private func closure(writing name: Name, with value: Warp.Expression, reading read: Warp.Expression? = nil) -> Warp.Expression {
        .closure(
            Procedure(
                signature: Signature(parameters: [], returns: .int),
                body: Body(
                    [Statement(binding: .assignment([.key(name)]), expression: value)]
                        + (read.map { read in [Statement(binding: .constant("read"), expression: read)] } ?? [])
                ),
                result: .literal(.int(0))
            )
        )
    }

    // A declaration answering its own `some T` by calling a value whose
    // type answers it, which nothing here proves of what the value is.
    private func unproven() -> Procedure {
        Procedure(
            signature: Signature(
                parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                returns: .parameter(name: "T")
            ),
            body: [
                Statement(
                    binding: .constant("back"),
                    expression: .closure(
                        Procedure(
                            signature: Signature(parameters: [], returns: .parameter(name: "T")),
                            body: [],
                            result: .reference([.key("x")])
                        )
                    )
                )
            ],
            result: .apply(.reference([.key("back")]), arguments: [])
        )
    }

    // A declaration taking and answering its own `some T`.
    private func generic(result: Warp.Expression) -> Procedure {
        Procedure(
            signature: Signature(
                parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                returns: .parameter(name: "T")
            ),
            body: [],
            result: result
        )
    }
}
