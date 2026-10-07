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
import WarpTestSupport

// What a loop puts back after a round that ended early.
//
// A round cut short has bound part of what a whole one binds, so where the
// result reads the body's slots the run puts them back to what the last whole
// round left. Which slots those are is read off the result before the link
// runs, and a call through a contract is the one that is still a contract at
// that moment: the calls beside it are the link's copy and are empty here.
@Suite("A loop whose result calls through a contract")
struct ContractCallKeepsTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("puts back what a round that ended early had bound", arguments: ["App.Show.show", "Bank.Box.show"])
    func aRoundCutShortIsPutBack(through: Name) async throws {
        // Given. A loop of three rounds that leaves in the third after binding
        // `k`, whose result hands `k` to a call on a value it was given. The
        // first argument is a parameter and the second is the body's, so a
        // walk that stops at the first sees nothing to put back.
        let loop = Warp.Expression.loop(
            while: .call(Call(
                selector: "Standard.Math.lessThan",
                arguments: [reference("round", "index"), .literal(.int(3))]
            )),
            body: Block(
                body: [
                    Statement(binding: .constant("k"), expression: reference("round", "index")),
                    Statement(expression: .conditional(
                        .call(Call(
                            selector: "Standard.Logic.equal",
                            arguments: [reference("round", "index"), .literal(.int(2))]
                        )),
                        then: [Statement(expression: .leave(Leave(reach: .construct)))],
                        else: nil
                    ))
                ],
                result: .call(Call(selector: through, arguments: [reference("it"), reference("k")]))
            )
        )

        let sut = try Module(
            types: ["Bank.Box": .record(["v": .int])],
            contracts: ["App.Show": ["show": Signature(parameters: [Parameter(name: "of", type: .selfType), Parameter(name: "with", type: .nullable(.int))], returns: .nullable(.int))]],
            claims: ["Bank.Box": ["App.Show"]],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .nullable(.int)),
                    body: [Statement(
                        binding: .constant("box"),
                        expression: .cast(.record(["v": .literal(.int(100))]), as: .named("Bank.Box"), optional: false)
                    )],
                    result: .call(Call(selector: "App.tell", arguments: [reference("box")]))
                ),
                "App.tell": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "it", type: through == "App.Show.show"
                                ? .parameter(name: "T", constraints: ["App.Show"])
                                : .named("Bank.Box"))
                        ],
                        returns: .nullable(.int)
                    ),
                    body: [Statement(binding: .constant("round"), expression: loop)],
                    result: reference("round")
                ),
                "Bank.Box.show": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .named("Bank.Box")),
                            Parameter(name: "with", type: .nullable(.int))
                        ],
                        returns: .nullable(.int)
                    ),
                    body: [],
                    result: reference("with")
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)
        let answered = try await Executor().run(image, entry: "App.entry", arguments: [:])

        // Then. The second round is the last whole one, and what it bound is
        // what the result reads. The third bound 2 and then left.
        #expect(answered == .int(1))
    }

    // MARK: - Public
    // MARK: - Private
}
