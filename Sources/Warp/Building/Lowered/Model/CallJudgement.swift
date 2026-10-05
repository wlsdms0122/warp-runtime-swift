//
//  CallJudgement.swift
//  Warp
//
//  Created by JSilver on 10/4/26.
//

import Foundation

// What a call is judged on where it stands: its answer against what the
// call reads it as, where the callee settles a wider one, and each variable
// it handed back in place against what the caller holds it as. At least
// one of the two is there; a call with neither is judged on nothing and
// stands bare.
struct CallJudgement: Sendable {
    // MARK: - Property
    let against: LoweredType?
    let handedBack: [HandedBack]

    // Whether the answer settles to what it is judged against: where that is
    // what a declaration wrote, the `returns` of a value's slot or an answer
    // a contract wrote, rather than what the call filled a type parameter
    // with, which the callee was handed or made and hands on as it came.
    let settlesAnswer: Bool

    // Whether what it is judged against names a type parameter: inside a
    // generic body, a judgement the run cannot hold to what filled it.
    var namesParameter: Bool {
        against?.namesParameter == true || handedBack.contains { back in back.against.namesParameter }
    }

    // MARK: - Initializer
    // Nil where there is nothing to judge.
    init?(against: LoweredType?, handedBack: [HandedBack], settlesAnswer: Bool) {
        guard against != nil || !handedBack.isEmpty else { return nil }

        self.against = against
        self.handedBack = handedBack
        self.settlesAnswer = settlesAnswer
    }

    // MARK: - Public
    // The same judgement with every type written another way.
    func rewritten(type: (LoweredType) throws -> LoweredType) rethrows -> CallJudgement {
        CallJudgement(
            rewriting: try against.map(type),
            handedBack: try handedBack.map { back in HandedBack(position: back.position, against: try type(back.against)) },
            settlesAnswer: settlesAnswer
        )
    }

    // MARK: - Private
    // Rewriting the types keeps what there is to judge, so it is never empty.
    private init(rewriting against: LoweredType?, handedBack: [HandedBack], settlesAnswer: Bool) {
        self.against = against
        self.handedBack = handedBack
        self.settlesAnswer = settlesAnswer
    }
}
