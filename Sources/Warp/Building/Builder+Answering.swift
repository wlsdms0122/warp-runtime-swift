//
//  Builder+Answering.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a declaration answers when nobody wrote it down.
//
// `returns` is optional because a declaration nobody wrote stays
// distinguishable from one somebody wrote, and for a long time the difference
// cost a call site nothing: an unwritten answer read as `any`, and `any` was
// accepted everywhere. It stopped being free when `any` became opaque. A dot on
// what such a call answers is refused, and the author is asked to write down a
// type the body already states.
//
// So the body is read. Not into the declaration: what the author wrote is
// what the image carries and what the boundary checks, and an answer worked
// out here is the link's own reading rather than anybody's promise. It reaches
// exactly as far as the readings do.
//
// A body's answer may be another body's, so the order is the call graph's. Each
// declaration read after everything its answer could come from. Bodies that
// reach one another's answers in a cycle, a recursive one included, are read
// as `any`: an answer worked out from itself is not one the text states, and a
// guess there would be a refusal an author cannot act on. Writing `returns` is
// what says more, and it removes the cycle by saying it.
extension Builder {
    // MARK: - Internal
    // A declaration whose answer nobody wrote, with what it takes to read one
    // off the body: the body itself, the names in scope before its first
    // statement, and which other unwritten answers its own may come from.
    struct Unsaid {
        // The declaration itself, rather than the two things this walk asks of
        // it. What it is called across the link and where its procedures are in the
        // document are both the symbol's to say, and copying either out here
        // would be a second place the rule for it lives.
        let symbol: Symbol

        let block: Block
        let environment: [Name: Binding]
        let sends: Set<Name>
    }

    // Every unwritten answer, read off its body, one at a time in the order the
    // call graph allows. Each handed back as it is worked out, and the context
    // asked for again, so the next body is read against it.
    //
    // Handed back rather than returned in a heap: the tables a context is made
    // of are the link's, one answer changes one entry in each, and rebuilding
    // them per declaration is the whole graph copied once per node.
    func answers(
        of unsaid: [Unsaid],
        reading context: () -> TypingContext,
        recording: (Name, LoweredType) -> Void
    ) async {
        let declared = Dictionary(
            unsaid.map { one in (one.symbol.declared, one) },
            uniquingKeysWith: { first, _ in first }
        )

        let edges = Dictionary(
            unsaid.map { one in (one.symbol.declared, one.sends.sorted()) },
            uniquingKeysWith: { first, _ in first }
        )

        for component in StronglyConnected.components(among: edges) {
            // One declaration that does not reach its own answer is the only
            // type a body can be read for. Everything else is a cycle, and
            // a cycle says nothing.
            guard
                component.count == 1,
                let only = component.first.flatMap({ name in declared[name] }),
                !only.sends.contains(only.symbol.declared)
            else {
                for name in component { recording(name, .any) }

                continue
            }

            // A refusal is the judging pass's to state, in its own terms and
            // at its own place. Raising one here would put the first refusal
            // an author sees somewhere the frontier never decided, so what
            // this pass cannot read it treats as unread.
            let read = try? await reading(
                from: only.block,
                at: only.symbol.place,
                in: only.environment,
                with: context()
            )

            // A reading naming a type parameter is handed on as it is. What a
            // parameter means is settled at the call, by the same filling a
            // declared `returns: some T` goes through, so a body answering its
            // own parameter answers what the caller put there, and a body
            // answering a type only it could name (what a walk *through* a
            // parameter reaches, named for the path that reached it) fills with
            // nothing, which is `any`. One rule, and the useful half comes for
            // free.
            recording(only.symbol.declared, read ?? .any)
        }
    }

    // Which declarations a body may read an answer from: every selector it
    // sends. Read off the one walk `Expression` owns.
    func sent(in block: Block) -> Set<Name> {
        block.subexpressions.reduce(into: Set<Name>()) { sent, expression in
            guard case let .call(call) = expression else { return }

            sent.insert(call.selector)
        }
    }

}
