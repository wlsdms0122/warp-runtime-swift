//
//  ValueRepresentable.swift
//  WarpMacros
//

import Foundation
import Warp

// A struct standing for the declared struct of this name, its stored
// properties the fields: the declaration, and the way to and from a `Value`.
@attached(extension, conformances: ValueRepresentable, names: named(type), named(declaration), named(init), named(value))
public macro ValueRepresentable(_ name: Name) = #externalMacro(module: "WarpMacrosPlugin", type: "ValueRepresentableMacro")
