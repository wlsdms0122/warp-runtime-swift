//
//  TypeName.swift
//  WarpMacrosPlugin
//

import SwiftSyntax

// The name a type is written under, without the module that may qualify it
// or the arguments that may follow it: `Query` for `Warp.Query`, `Invocation`
// for `Invocation<Self>`.
struct TypeName {
    // MARK: - Property
    let text: String?

    // MARK: - Initializer
    init(_ type: TypeSyntax) {
        if let member = type.as(MemberTypeSyntax.self) {
            self.text = member.name.text
        } else {
            self.text = type.as(IdentifierTypeSyntax.self)?.name.text
        }
    }

    // MARK: - Public
    // MARK: - Private
}
