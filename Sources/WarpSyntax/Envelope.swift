//
//  Envelope.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// What a document says about itself before anything reads what it says.
//
// A program that stays where it was built needs none of this — the thing that
// built it is the thing that runs it. A program that travels does: it arrives at
// something that may be older than the program is, may not have the words the
// program calls, and cannot ask the sender anything. Both questions have to be
// answerable from the bytes alone, and both have to be answerable *before* the
// program runs, because half-running one is worse than refusing it.
public enum Envelope {
    // MARK: - Property
    // Which shapes a reader has to understand. It goes up when a shape is added
    // or an existing one changes what it means, and does not move for a new word
    // — a word is vocabulary, and vocabulary is what `needs` is for.
    //
    // Every document says it. A reader that filled in a default would be reading
    // a document that never said which language it was written for, and a file
    // that is not a document at all would get as far as having its keys judged —
    // turned away for being a malformed module rather than for not being one.
    //
    // Nothing has shipped, so there is nothing old to hold a number for — every
    // change before the first release folds into this one. The counter starts
    // moving when a document exists somewhere this code does not control.
    public static let version = 1
    public static let earliest = 1

    public static let versionKey = "warp"
    public static let needsKey = "needs"

    // MARK: - Public
    // The words a document sends and does not declare. Every one has to be
    // declared by something in the link or the program cannot run, so this is
    // what a reader needs from elsewhere, listed rather than discovered.
    //
    // Sent, not reached. A path reaches words too — `x.count` is one — but only
    // ones that answer without running, since that is the whole of what makes a
    // path safe to walk. So what is listed here is everything the program can do
    // that touches anything, and a caller reading it is reading the bounds of
    // what it is about to allow.
    public static func needs(of module: Module) -> Set<String> {
        // A constant is an expression, so it sends words like any other. Missing
        // them would understate what a program needs, and the list is only worth
        // having if it can be believed.
        module.constants.values
            .reduce(into: Set()) { sent, constant in
                sent.formUnion(selectors(in: constant.buried))
            }
            .union(
                module.procedures.values.reduce(into: Set()) { sent, procedure in
                    guard case let .body(block) = procedure.implementation else { return }

                    sent.formUnion(selectors(in: block.buried))
                }
            )
            .subtracting(module.procedures.keys)
    }

    // MARK: - Private
    // The selectors an expression sends, however deep. The walk is the one
    // `Expression` owns — a closure is a body that runs later and what it
    // sends is still sent, a cast sends nothing and what it reads may — and
    // this says only which of what the walk finds is a send.
    private static func selectors(in buried: [Expression]) -> Set<String> {
        buried.reduce(into: Set()) { sent, expression in
            guard case let .dispatch(dispatch) = expression else { return }

            sent.insert(dispatch.selector)
        }
    }
}
