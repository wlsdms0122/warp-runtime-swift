//
//  Query.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that answers without running anything.
// `count`, `contains`, whatever a module ships. Const, which is what lets it
// be asked inside a condition and while a constant settles.
//
// It carries no name and no signature. Both belong to the `Procedure` that has
// this as its implementation. The name is the key its module declares it under,
// the same as any other declaration, and the signature is what a call site is
// checked against whichever way the body is written.
public protocol Query: NativeProcedure {
    func evaluate(_ question: Question<Self>) async throws -> Value
}
