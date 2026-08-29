//
//  SymbolSpace.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// The procedure namespace, prepared once. Resolution is asked for every
// dispatch in every body — and again on every round of the purity fixed point —
// so what it reads is gathered here rather than rebuilt at each question: the
// declared spellings as one set, and each module's own declarations by origin.
struct SymbolSpace {
    // MARK: - Property
    private let spellings: [String: Symbol]
    private let owned: [Int: [String]]
    private let declared: Set<String>

    // MARK: - Initializer
    // Qualified spellings are unique — the symbol gathering refused a double —
    // so keying by them keeps every declaration.
    init(_ symbols: [Symbol]) {
        let spellings = symbols.reduce(into: [String: Symbol]()) { table, symbol in
            table[symbol.qualified] = symbol
        }

        self.spellings = spellings
        self.owned = symbols.reduce(into: [:]) { table, symbol in
            table[symbol.origin, default: []].append(symbol.qualified)
        }
        self.declared = Set(spellings.keys)
    }

    // MARK: - Public
    // The space with nothing in it — what a body whose names are already
    // resolved is judged against, held once rather than rebuilt per question.
    static let empty = SymbolSpace([])

    // The one resolution rule, asked in this space.
    func resolution(of name: String, from origin: Int?) -> Resolution {
        Linker.resolution(
            of: name,
            owned: origin.flatMap { origin in owned[origin] } ?? [],
            among: declared
        )
    }

    // The declaration a spelling settles on, or nil where the rule cannot
    // settle — the caller that wants the two failures apart asks
    // `resolution(of:from:)` instead.
    func resolve(_ name: String, from origin: Int?) -> Symbol? {
        guard case let .resolved(qualified) = resolution(of: name, from: origin) else {
            return nil
        }

        return spellings[qualified]
    }

    // The declaration under one settled spelling — for a caller that switched
    // on `resolution(of:from:)` itself and holds a `.resolved` answer.
    func symbol(spelled qualified: String) -> Symbol? {
        spellings[qualified]
    }

    // MARK: - Private
}
