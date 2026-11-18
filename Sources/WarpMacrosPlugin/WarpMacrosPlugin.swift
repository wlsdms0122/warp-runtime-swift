//
//  WarpMacrosPlugin.swift
//  WarpMacrosPlugin
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WarpMacrosPlugin: CompilerPlugin {
    // MARK: - Property
    let providingMacros: [any Macro.Type] = [
        ValueRepresentableMacro.self,
        ProcedureConvertibleMacro.self
    ]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
