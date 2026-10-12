//
//  Vocabulary.swift
//  WarpBench
//
//  Created by JSilver on 9/11/26.
//

import Foundation
import Warp
import WarpStandard

// A vocabulary held the way a host that brings the same procedures every run
// holds it: the documents compiled once, and laid down once against the native
// code behind them.
//
// Every build here is compiled against the standard one, so what a figure
// moves with is the build's own procedures rather than the ones it always
// costs.
struct Vocabulary: Sendable {
    // MARK: - Property
    // Loaded once and awaited by everyone who reads it. A compile suspends
    // and a stored property cannot, so what is held here is the loading
    // rather than the answer.
    static let standard = Task { try await Vocabulary(Module.standard) }

    let laid: Laid
    let brought: Supplying

    // MARK: - Initializer
    init(_ modules: [Module]) async throws {
        let brought = try Supplying(modules)

        self.laid = try Builder().lay(try await Builder().compile(modules), supplying: brought)
        self.brought = brought
    }

    // MARK: - Public
    // MARK: - Private
}
