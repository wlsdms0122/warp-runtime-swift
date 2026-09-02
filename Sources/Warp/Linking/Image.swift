//
//  Image.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure together with every procedure it can reach, resolved. Only `Linker`
// makes one, so holding a value of this type is the evidence that linking
// happened — the executor takes an image rather than a procedure so that "ran
// without linking" has no spelling.
public struct Image: Sendable {
    // MARK: - Property
    public let entry: Procedure

    // Keyed by the name the call site used, which is what the executor looks a
    // callee up by. Transitive: a procedure reached only through another procedure
    // is in here too.
    public let procedures: [String: Procedure]

    // Every shape the linked modules declared. A named type survives into the
    // run rather than being expanded at link, so the run needs the table that
    // answers it.
    public let types: TypeTable

    // Which of them answer without running. Computed here rather than declared,
    // because for a body it is a fact about what it calls — and a fact the
    // whole call graph has to be walked to know.
    public let pure: Set<String>

    // What a selector may send without running, by the qualified spelling a
    // selector writes: the pure declarations, bodies and native words alike.
    public let selectors: [String: Procedure]

    // What a bare spelling a path writes may send — its own table, because a
    // selector and a path spelling are two questions one key must not answer
    // for each other.
    public let words: [String: Procedure]

    // MARK: - Initializer
    init(
        entry: Procedure,
        procedures: [String: Procedure],
        types: TypeTable,
        pure: Set<String>,
        selectors: [String: Procedure],
        words: [String: Procedure]
    ) {
        self.entry = entry
        self.procedures = procedures
        self.types = types
        self.pure = pure
        self.selectors = selectors
        self.words = words
    }

    // MARK: - Public
    // MARK: - Private
}
