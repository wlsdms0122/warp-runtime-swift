//
//  SymbolSpace.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// The procedure namespace, prepared once. A send names a declaration by its
// qualified spelling and nothing else, so the space is that spelling's table:
// every dispatch in every body asks it, and what it reads is gathered here
// rather than rebuilt at each question.
struct SymbolSpace {
    // MARK: - Property
    private let spellings: [String: Symbol]

    // MARK: - Initializer
    // Qualified spellings are unique — the symbol gathering refused a double —
    // so keying by them keeps every declaration.
    init(_ symbols: [Symbol]) {
        self.spellings = symbols.reduce(into: [String: Symbol]()) { table, symbol in
            table[symbol.qualified] = symbol
        }
    }

    // MARK: - Public
    // The declaration under one spelling, or nil where no module declares it.
    func symbol(spelled qualified: String) -> Symbol? {
        spellings[qualified]
    }

    // MARK: - Private
}
