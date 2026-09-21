//
//  TypingContext.swift
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
struct TypingContext: Sendable {
    // MARK: - Property
    // The declared types as the documents wrote them, for the surfaces a
    // document's own spelling is owed to.
    let types: TypeTable

    // The rows the link built, and which row each declared spelling stands
    // on. What a declaration takes and answers is read off its row: the row
    // is the declaration lowered, and a second table of the same facts would
    // hash every declared name to say what the row already says.
    let linked: [Linked]
    let rows: [Name: Int]

    // The declarations of the document being read, by row, private ones
    // included. Read before the link's spellings.
    let own: [Name: Int]

    // What the link read off a body whose declaration wrote no `returns`.
    // Only those, for the same reason: what a declaration wrote is on its row.
    let answers: [Int: LoweredType]

    // The same declarations as the run reads them, lowered once. Every
    // judgment the walk asks goes here, so the walk and the run judge by one
    // table and by one language.
    var loweredTypes: LoweredTypeTable { types.loweredTypes }

    // Every contract's procedures, under the spelling a call writes to reach one.
    // Beside the symbols rather than in them: a name here answers with no
    // declaration, and which declaration runs is the receiver's to say.
    let contractProcedures: [Name: ContractProcedure]

    // The variables of the document being read, by name. A body reading one
    // answers by the run's state, so constness is read against these.
    let variables: Set<Name>

    // MARK: - Initializer
    // MARK: - Public
    // What a call is written against: the whole signature rather than what it
    // answers, because a declaration with a type parameter in it does not
    // answer anything until a call site fills it, and what fills it is read
    // from the arguments.
    func signature(of selector: Name) -> Signature? {
        declared(selector)?.signature
    }

    // The row a selector names. A walk that meets a call finds it here, once,
    // and hands the spelling on with the call so nothing finds it again.
    func declared(_ selector: Name) -> Linked? {
        (own[selector] ?? rows[selector]).map { row in linked[row] }
    }

    // What a selector takes: the slots of the row it stands on, or the ones a
    // contract lowered for its procedure, which stands on no row.
    func slots(of selector: Name) -> [Slot] {
        if let row = own[selector] ?? rows[selector] { return linked[row].slots }

        return contractProcedures[selector]?.slots ?? []
    }

    // What it answers: what the link read off a body that declared none, else
    // what the declaration wrote.
    func answer(of selector: Name) -> LoweredType? {
        if let row = own[selector] ?? rows[selector] { return answers[row] ?? linked[row].returns }

        return contractProcedures[selector]?.answers
    }

    // What the build derived of the declaration a selector names, read off
    // its row. A selector naming no row, a contract's procedure among them,
    // has none of these.
    func isConst(_ selector: Name) -> Bool {
        declared(selector)?.constness == .const
    }

    func isIsolated(_ selector: Name) -> Bool {
        declared(selector)?.isolation == .isolated
    }

    func failing(of selector: Name) -> Failing? {
        declared(selector)?.failing
    }

    // A named type stands for what it was declared as. Inference walks into
    // types, so it has to look through a name to find one. The table lowered
    // every declaration once, so following a name is reading a row.
    func resolve(_ type: LoweredType) -> LoweredType {
        guard case let .named(row) = type else { return type }

        return resolve(loweredTypes.loweredTypes[row])
    }

    // MARK: - Private
}
