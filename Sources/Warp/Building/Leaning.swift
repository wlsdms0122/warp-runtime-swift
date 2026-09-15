//
//  Leaning.swift
//  Warp
//
//  Created by JSilver on 9/16/26.
//

import Foundation

// Which artifact declares each name a compile can reach, as the documents are
// laid down one at a time.
//
// A document reaches outside itself through the procedures it calls and the
// types its signatures name, which is what `Module.uses` already holds: every
// procedure and type it names and does not declare. So what a document leaned
// on is read off the document rather than tracked through the compile.
//
// It grows as the compile lays documents down, because a document laid here may
// be what the next one leans on. The order the compile lays them in already
// stands each one's needs before it, so a name is in here by the time anything
// asks for it.
struct Leaning {
    // MARK: - Property
    // Nothing for a document that has no fingerprint. The name is declared and
    // the answer is that there is nothing to record, which is not the same as
    // a name nothing declares.
    private var declares: [Reference: Fingerprint?] = [:]

    // MARK: - Initializer
    // MARK: - Internal
    // One document laid down, under what it turned out to be.
    mutating func lay(_ document: Compiled) {
        hold(
            document.declared.map(Reference.procedure)
                + document.types.keys.map(Reference.type)
                + document.constraints.keys.map(Reference.type)
                + document.contracts.keys.map(Reference.type),
            as: document.fingerprint
        )
    }

    // What this document was compiled against, or nothing where one of the
    // artifacts it named has no fingerprint.
    func leaned(by module: Module) -> [Fingerprint]? {
        var leaned: Set<Fingerprint> = []

        for used in module.uses {
            // A name nothing here declares is left alone. The link refuses it,
            // and refusing here would be a second copy of a rule that has to be
            // right once.
            guard let declared = declares[used] else { continue }

            guard let fingerprint = declared else { return nil }

            leaned.insert(fingerprint)
        }

        // In byte order, so a set leaves as one sequence however it was
        // gathered.
        return leaned.sorted()
    }

    // MARK: - Private
    // A name two documents declare is held to one declarer before this is
    // asked, so the first answer stands.
    private mutating func hold(_ declared: [Reference], as fingerprint: Fingerprint?) {
        for reference in declared where declares[reference] == nil {
            declares[reference] = .some(fingerprint)
        }
    }
}
