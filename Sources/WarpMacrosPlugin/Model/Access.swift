//
//  Access.swift
//  WarpMacrosPlugin
//

import SwiftSyntax

// The access a generated member takes: the one the type it is generated on
// declares, so a public type's conformance is public.
struct Access {
    // MARK: - Property
    let prefix: String

    // MARK: - Initializer
    init(of declaration: some DeclGroupSyntax) {
        let keywords: [Keyword] = [.public, .package]

        self.prefix = declaration.modifiers
            .first { modifier in keywords.contains { keyword in modifier.name.tokenKind == .keyword(keyword) } }
            .map { modifier in "\(modifier.name.text) " } ?? ""
    }

    // MARK: - Public
    // MARK: - Private
}
