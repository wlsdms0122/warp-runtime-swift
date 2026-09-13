//
//  ContractCallKeepsTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What a loop puts back after a round that ended early.
//
// A round cut short has bound part of what a whole one binds, so where the
// result reads the body's slots the run puts them back to what the last whole
// round left. Which slots those are is read off the result before the link
// runs, and a call through a contract is the one that is still a contract at
// that moment: the calls beside it are the link's copy and are empty here.
//
// The two ways of writing one call stand side by side, because a contract that
// answered differently from the declaration behind it is the failure this is
// about.
@Suite("A loop whose result calls through a contract")
struct ContractCallKeepsTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("puts back what a round that ended early had bound", arguments: ["app.Show.show", "bank.Box.show"])
    func aRoundCutShortIsPutBack(through: Name) async throws {
        // Given. A loop of three rounds that leaves in the third after binding
        // `k`, whose result hands `k` to a call on a value it was given. The
        // receiver is a parameter and the argument is the body's, so a walk
        // that stops at the receiver sees nothing to put back.
        let loop = Warp.Expression.loop(
            while: .call(Call(
                receiver: reference("round", "index"),
                selector: "std.math.lessThan",
                arguments: ["value": .literal(.int(3))]
            )),
            body: Block(
                body: [
                    Statement(binding: .constant("k"), expression: reference("round", "index")),
                    Statement(expression: .conditional(
                        .call(Call(
                            receiver: reference("round", "index"),
                            selector: "std.logic.equal",
                            arguments: ["value": .literal(.int(2))]
                        )),
                        then: [Statement(expression: .leave(Leave(reach: .construct)))],
                        else: nil
                    ))
                ],
                result: .call(Call(
                    receiver: reference("it"),
                    selector: through,
                    arguments: ["with": reference("k")]
                ))
            ),
            round: "round"
        )

        let sut = try Module(
            types: ["bank.Box": .record(["v": .int])],
            contracts: ["app.Show": ["show": Signature(parameters: ["with": Parameter(type: .nullable(.int))], returns: .nullable(.int))]],
            claims: ["bank.Box": ["app.Show"]],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .nullable(.int)),
                    body: [Statement(
                        binding: .constant("box"),
                        expression: .cast(.record(["v": .literal(.int(100))]), as: .named("bank.Box"), optional: false)
                    )],
                    result: .call(Call(selector: "app.tell", arguments: ["it": reference("box")]))
                ),
                "app.tell": Procedure(
                    signature: Signature(
                        parameters: [
                            "it": Parameter(type: through == "app.Show.show"
                                ? .parameter(name: "T", constraint: "app.Show")
                                : .named("bank.Box"))
                        ],
                        returns: .nullable(.int)
                    ),
                    body: [],
                    result: loop
                ),
                "bank.Box.show": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .named("bank.Box")),
                            "with": Parameter(type: .nullable(.int))
                        ],
                        returns: .nullable(.int)
                    ),
                    body: [],
                    result: reference("with")
                )
            ]
        )

        // When
        let image = try Builder().build([sut] + Module.standard, entry: "app.entry")
        let answered = try await Executor().run(image, arguments: [:])

        // Then. The second round is the last whole one, and what it bound is
        // what the result reads. The third bound 2 and then left.
        #expect(answered == .int(1))
    }

    // MARK: - Public
    // MARK: - Private
}
