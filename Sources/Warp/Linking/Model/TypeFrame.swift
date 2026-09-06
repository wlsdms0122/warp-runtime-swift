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
// are one fact (the link's answer to "what does this name mean") read from two
// sides.
struct TypeFrame: Sendable {
    // MARK: - Property
    // Every declaration under its declared spelling, as the author wrote it.
    // A walk that meets a call finds the declaration here, once, and hands it
    // on with the call. The same spellings key `signatures`, where the link
    // has filled in what each declaration answers.
    let symbols: [Name: Symbol]

    // Keyed by the resolved selector for a call, and by that alone: the bare
    // spelling a path writes lives in `words`, because the two spellings ask
    // two different questions.
    //
    // Whole signatures rather than what each answers, because a declaration
    // with a type parameter in it does not answer anything until a call site
    // fills it, and what fills it is read from the arguments.
    let signatures: [Name: Signature]

    // The declared types as the documents wrote them, for the surfaces a
    // document's own spelling is owed to.
    let types: TypeTable

    // What each declaration answers, as the link reads it: the `returns` it
    // wrote, lowered, or what the link read off a body nobody wrote one for.
    // Beside the signatures rather than written into them, because a signature
    // is the author's spelling and this is the link's reading, and no document
    // spells a row.
    let answers: [Name: Shape]

    // Each declaration's parameters as the run reads them, lowered once with
    // the rows and read here. Every call site is judged against these, so a
    // declaration is lowered per link rather than per call.
    let slots: [Name: [Slot]]

    // The same declarations as the run reads them, lowered once. Every
    // judgment the walk asks goes here, so the walk and the run judge by one
    // table and by one language.
    var shapes: ShapeTable { types.shapes }

    // What a bare spelling a path writes may call: the pure declarations whose
    // only required slot is the receiver, by the name a walk reaches them
    // under. Its own table rather than a mask over `signatures`, so the gate
    // and the declaration it answers with cannot disagree.
    let words: [Name: Signature]

    // What each of those answers, read the same way, under the spelling a path
    // reaches it by.
    let wordAnswers: [Name: Shape]

    // Their parameters, lowered once, under the same spelling.
    let wordSlots: [Name: [Slot]]

    // Every declaration that answers without running, by resolved selector. A
    // closure literal is judged against this, so what a body is written to call
    // decides whether it fits a slot asking for purity.
    let pure: Set<Name>

    // Which declarations touch no name another body could touch at the same
    // time, worked out from the bodies the way purity is.
    let isolated: Set<Name>

    // What may come out of each declaration when the work goes wrong, worked
    // out from the bodies the way purity is. A closure literal is judged
    // against this, and so is every `attempt`: what a rescue is there for is
    // what its body may fail with.
    let failing: [Name: Failing]

    // Every contract's words, under the spelling a call writes to reach one.
    // Beside the symbols rather than in them: a name here answers with no
    // declaration, and which declaration runs is the receiver's to say.
    let contractWords: [Name: ContractWord]

    // Each document's variables by name. A body reading one answers by the
    // run's state, so purity is read against these.
    let variables: [Int: Set<Name>]

    // MARK: - Initializer
    // MARK: - Public
    // The whole declaration, for the one call a path makes, and only where a
    // path may make it. There is no way to ask what a name answers without
    // asking whether a path may call it. A softer question was how a word
    // nobody may reach got a type.
    func signature(reachedBy name: Name) -> Signature? {
        words[name]
    }

    // A named type stands for what it was declared as. Inference walks into
    // shapes, so it has to look through a name to find one. The table lowered
    // every declaration once, so following a name is reading a row.
    func resolve(_ shape: Shape) -> Shape {
        guard case let .named(row) = shape else { return shape }

        return resolve(shapes.shapes[row])
    }

    // MARK: - Private
}
