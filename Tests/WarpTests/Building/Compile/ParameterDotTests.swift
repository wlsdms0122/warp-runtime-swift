//
//  ParameterDotTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// A dot on a type parameter. The type is the call's fact, so the build leaves
// the segments as written rather than judging on nothing.
@Suite("A dot on a type parameter")
struct ParameterDotTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a dot on some T reads the field the call filled in")
    func aDotOnAParameterReadsData() async throws {
        // Given. The procedure's body reads `of.count`; the call fills T with a
        // record carrying `count`, and the field wins because nothing here ever
        // judged the dot a procedure
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .parameter(name: "T"))],
                        returns: .any
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("count")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(selector: "peek", arguments: [.record(["count": .literal(.string("mine"))])]))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .string("mine"))
    }

    @Test("naming a step through a parameter does not change what the path means")
    func aNamedStepStillReadsOn() async throws {
        // Given. `of.inner.count` written as two statements. The step is a
        // type the call decides, the way the parameter is, so the dot after it
        // stands as written and the call's value answers it
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .parameter(name: "T"))],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("held"), expression: .reference([.key("of"), .key("inner")]))
                    ],
                    result: .reference([.key("held"), .key("count")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .record([
                                "inner": .record(["count": .literal(.string("mine"))])
                            ])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .string("mine"))
    }

    @Test("what was read out of a parameter is not the parameter")
    func aStepIsNotTheParameterItCameThrough() async throws {
        // Given. One name written twice: once the parameter, once a field of
        // it. They are two unknowns, not one (`of` is the type the call filled
        // in and `of.inner` is a field of that type) so the name holds neither
        // reading and a dot on it is refused.
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "flag", type: .bool),
                            Parameter(name: "of", type: .parameter(name: "T"))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .reference([.key("of")])),
                        Statement(
                            expression: .conditional(
                                equals(.reference([.key("flag")]), .literal(.bool(true))),
                                then: [
                                    Statement(binding: .assignment([.key("held")]), expression: .reference([.key("of"), .key("inner")]))
                                ],
                                else: nil
                            )
                        )
                    ],
                    result: .reference([.key("held"), .key("count")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .literal(.bool(true)),
                            .record(["inner": .record(["count": .literal(.string("mine"))])])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which declares nothing")
        }
    }

    @Test("one field is one type, however the walk that reached it was marked")
    func aMarkDoesNotSplitTheField() async throws {
        // Given. The same field of the same parameter, reached once plainly and
        // once through a mark. What a mark says is expected of the value; where
        // the walk landed is the field either way, so the two readings are one
        // type and a dot on it stands.
        func module(marking: Bool) throws -> Module {
            try Module(
                procedures: [
                    "peek": Procedure(
                        signature: Signature(
                            parameters: [
                                Parameter(name: "flag", type: .bool),
                                Parameter(name: "of", type: .parameter(name: "T"))
                            ],
                            returns: .any
                        ),
                        body: [
                            Statement(binding: .variable("held"), expression: .reference([.key("of"), .key("inner")])),
                            Statement(
                                expression: .conditional(
                                    equals(.reference([.key("flag")]), .literal(.bool(true))),
                                    then: [
                                        Statement(binding: .assignment([.key("held")]), expression: .reference([
                                                .key("of"),
                                                .key("inner", optional: marking)
                                            ])
                                        )
                                    ],
                                    else: nil
                                )
                            )
                        ],
                        result: .reference([.key("held"), .key("count")])
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .any),
                        body: [],
                        result: .call(Call(
                            selector: "peek",
                            arguments: [
                                .literal(.bool(true)),
                                .record(["inner": .record(["count": .literal(.int(1))])])
                            ]
                        ))
                    )
                ]
            )
        }

        // When / Then. Written the same way twice, and written two ways, build
        // alike
        for marking in [false, true] {
            _ = try await builder.build([module(marking: marking)] + Module.standard)
        }
    }

    @Test("naming a step on the way does not make it a second unknown")
    func aNamedStepArrivesWhereTheWalkArrives() async throws {
        // Given. The same field of the same parameter, reached once in a single
        // walk and once through a name given to a step along the way. A body
        // may hold what it read, and holding it is not reading something else.
        // The root is the parameter, so a name in between changes nothing about
        // where the walk landed.
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "flag", type: .bool),
                            Parameter(name: "of", type: .parameter(name: "T"))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("held"), expression: .reference([.key("of"), .key("inner")])),
                        Statement(binding: .variable("seen"), expression: .reference([.key("of"), .key("inner"), .key("count")])),
                        Statement(expression: .conditional(
                            equals(.reference([.key("flag")]), .literal(.bool(true))),
                            then: [Statement(binding: .assignment([.key("seen")]), expression: .reference([.key("held"), .key("count")])
                            )],
                            else: nil
                        ))
                    ],
                    result: .reference([.key("seen"), .key("deep")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .literal(.bool(true)),
                            .record([
                                "inner": .record(["count": .record(["deep": .literal(.int(1))])])
                            ])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("one unknown is one unknown, whichever parameter it was read through")
    func oneUnknownIsReadThroughEitherParameter() async throws {
        // Given. Two parameters of the same type parameter. A call fills `T`
        // once, so they hold one type, and the same field of it read through
        // either name is the same field.
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "also", type: .parameter(name: "T")),
                            Parameter(name: "flag", type: .bool),
                            Parameter(name: "of", type: .parameter(name: "T"))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .variable("seen"), expression: .reference([.key("of"), .key("inner")])),
                        Statement(expression: .conditional(
                            equals(.reference([.key("flag")]), .literal(.bool(true))),
                            then: [Statement(binding: .assignment([.key("seen")]), expression: .reference([.key("also"), .key("inner")])
                            )],
                            else: nil
                        ))
                    ],
                    result: .reference([.key("seen"), .key("count")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .record(["inner": .record(["count": .literal(.int(2))])]),
                            .literal(.bool(true)),
                            .record(["inner": .record(["count": .literal(.int(1))])])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    // MARK: - Public
    // MARK: - Private
}
