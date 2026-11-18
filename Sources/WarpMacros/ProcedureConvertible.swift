//
//  ProcedureConvertible.swift
//  WarpMacros
//

import Foundation
import Warp

// A native procedure declared from the Swift function it does its work in:
// its parameters and what it returns, under this name.
// What follows the name is the rest of its `Signature`.
@attached(
    extension,
    conformances: ProcedureConvertible,
    names: named(Parameters), named(name), named(procedure), named(run), named(evaluate), named(compute)
)
public macro ProcedureConvertible(
    _ name: Name,
    failing: Failing = .these([]),
    constness: Constness = .unstated,
    isolation: Isolation = .unstated
) = #externalMacro(module: "WarpMacrosPlugin", type: "ProcedureConvertibleMacro")
