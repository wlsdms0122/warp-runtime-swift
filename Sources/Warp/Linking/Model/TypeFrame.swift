//
//  TypeFrame.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What inference needs beyond the body it is reading: what every declaration in
// the link answers with, and what every name in it stands for.
//
// One value rather than two arguments threaded through every walk, because they
// are one fact — the link's answer to "what does this name mean" — read from two
// sides.
struct TypeFrame: Sendable {
    // MARK: - Property
    // Keyed by the resolved selector for a call — and by that alone: the
    // bare spelling a path writes lives in `words`, because the two spellings
    // ask two different questions.
    //
    // Whole signatures rather than what each answers, because a declaration
    // with a type parameter in it does not answer anything until a call site
    // fills it — and what fills it is read from the arguments.
    let signatures: [String: Signature]

    let types: TypeTable

    // What a bare spelling a path writes may send: the pure declarations whose
    // only required slot is the receiver, by the name a walk reaches them
    // under. Its own table rather than a mask over `signatures`, so the gate
    // and the declaration it answers with cannot disagree.
    let words: [String: Signature]

    // Every declaration that answers without running, by resolved selector. A
    // closure literal is judged against this, so what a body is written to call
    // decides whether it fits a slot asking for purity.
    let pure: Set<String>

    // MARK: - Initializer
    // MARK: - Public
    // The whole declaration, for the one send a path makes — and only where a
    // path may make it. There is no way to ask what a name answers without
    // asking whether a path may send it — a softer question was how a word
    // nobody may reach got a type.
    func signature(reachedBy name: String) -> Signature? {
        words[name]
    }

    // A named type stands for what it was declared as. Inference walks into
    // shapes, so it has to look through a name to find one.
    func resolve(_ type: TypeExpression) -> TypeExpression {
        guard case let .named(name) = type, let declared = types.resolve(name) else {
            return type
        }

        return resolve(declared)
    }

    // MARK: - Private
}
