//
//  Linker+Answering.swift
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
// accepted everywhere. It stopped being free when `any` became opaque — a dot
// on what such a call answers is refused, and the author is asked to write
// down a shape the body already states.
//
// So the body is read. Not into the declaration: what the author wrote is
// what the image carries and what the boundary checks, and an answer worked
// out here is the link's own reading rather than anybody's promise. It reaches
// exactly as far as the readings do.
//
// A body's answer may be another body's, so the order is the call graph's —
// each declaration read after everything its answer could come from. Bodies
// that reach one another's answers in a circle, a recursive one included, are
// read as `any`: an answer worked out from itself is not one the text states,
// and a guess there would be a refusal an author cannot act on. Writing
// `returns` is what says more, and it removes the circle by saying it.
extension Linker {
    // MARK: - Internal
    // A declaration whose answer nobody wrote, with what it takes to read one
    // off the body: the body itself, the names in scope before its first
    // statement, and which other unwritten answers its own may come from.
    struct Unsaid {
        // The declaration itself, rather than the two things this walk asks of
        // it. What it is called across the link and where its words are in the
        // document are both the symbol's to say, and copying either out here
        // would be a second place the rule for it lives.
        let symbol: Symbol

        let block: Block
        let environment: [String: TypeExpression]
        let sends: Set<String>
    }

    // Every unwritten answer, read off its body, one at a time in the order
    // the call graph allows — each handed back as it is worked out, and the
    // frame asked for again, so the next body is read against it.
    //
    // Handed back rather than returned in a heap: the tables a frame is made
    // of are the link's, one answer changes one entry in each, and rebuilding
    // them per declaration is the whole graph copied once per node.
    func answers(
        of unsaid: [Unsaid],
        reading frame: () -> TypeFrame,
        recording: (String, TypeExpression) -> Void
    ) {
        let declared = Dictionary(
            unsaid.map { one in (one.symbol.qualified, one) },
            uniquingKeysWith: { first, _ in first }
        )

        let edges = Dictionary(
            unsaid.map { one in (one.symbol.qualified, one.sends.sorted()) },
            uniquingKeysWith: { first, _ in first }
        )

        for circle in Circles.among(edges) {
            // One declaration that does not reach its own answer is the only
            // shape a body can be read for. Everything else is a circle, and
            // a circle says nothing.
            guard
                circle.count == 1,
                let only = circle.first.flatMap({ name in declared[name] }),
                !only.sends.contains(only.symbol.qualified)
            else {
                for name in circle { recording(name, .any) }

                continue
            }

            // The reading ask refuses nothing — what it cannot read is `any`
            // — so nothing is expected out of here. The belt is for the day
            // that changes: a refusal is the judging pass's to state, in its
            // own words and at its own place, and stating one here would put
            // the first refusal an author sees somewhere the frontier never
            // decided.
            let read = try? reading(
                from: only.block,
                at: only.symbol.place,
                in: only.environment,
                with: frame()
            )

            // A reading naming a type parameter is handed on as it is. What a
            // parameter means is settled at the call, by the same filling a
            // declared `returns: some T` goes through — so a body answering
            // its own parameter answers what the caller put there, and a body
            // answering a shape only it could name (what a walk *through* a
            // parameter reaches, named for the path that reached it) fills
            // with nothing, which is `any`. One rule, and the useful half
            // comes for free.
            recording(only.symbol.qualified, read ?? .any)
        }
    }

    // Which declarations a body may read an answer from. Every selector it
    // sends, and every name a path writes that a walk could reach a word by —
    // a path sends words too, and a word's answer is an answer like any
    // other.
    //
    // Read off the one walk `Expression` owns, and read wide: a name gathered
    // that turns out not to be a send only ever adds an edge, and an edge
    // only ever turns a reading into `any`. Missing one would do the
    // opposite.
    func sent(in block: Block, reaching words: [String: Symbol]) -> Set<String> {
        var sent: Set<String> = []

        func gather(_ path: [PathSegment]) {
            for segment in path {
                if let name = segment.named, let word = words[name] {
                    sent.insert(word.qualified)
                }

                guard case let .indexRef(inner, _) = segment else { continue }

                gather(inner)
            }
        }

        for expression in block.buried {
            switch expression {
            case let .dispatch(dispatch):
                sent.insert(dispatch.selector)

            case let .reference(path):
                gather(path)

            default:
                break
            }
        }

        return sent
    }

}
