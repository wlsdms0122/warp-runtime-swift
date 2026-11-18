//
//  Computation.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A query that answers from what its call wrote alone. It sends nothing and
// calls nothing, so a run asks it without waiting on anything. Its declaration
// may say it is const, as any query's may.
public protocol Computation: Query where Imports == NoImports {
    func compute(_ arguments: Arguments<Self>) throws -> Value

    // The same from arguments it keeps: a call that moved a variable's value
    // to it hands the value over, so one that takes the argument and writes
    // it writes that value rather than a copy. The default computes from
    // them as they are.
    func compute(taking arguments: consuming Arguments<Self>) throws -> Value

    // The entry a run asks through. The default is compiled where the
    // procedure's type is concrete, so the arguments are read for that type and
    // not looked up by it.
    func answer(_ given: Given) throws -> Value
}

extension Computation {
    @inlinable
    public func answer(_ given: Given) throws -> Value {
        try compute(Arguments(given))
    }

    @inlinable
    public func compute(taking arguments: consuming Arguments<Self>) throws -> Value {
        try compute(arguments)
    }

    // Asked the way any query is, through a send or as the entry a run starts
    // from, it answers from the same arguments, so every way a run reaches it
    // computes.
    @inlinable
    public nonisolated(nonsending) func answer(_ asked: Asked) async throws -> Value {
        try answer(Given(asked.arguments.values))
    }

    public nonisolated(nonsending) func evaluate(_ question: Question<Self>) async throws -> Value {
        try answer(Given(question.asked.arguments.values))
    }
}
