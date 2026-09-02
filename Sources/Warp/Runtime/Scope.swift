//
//  Scope.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// The environment: which names exist here and what each one holds. A scope
// answers about a head and nothing further — walking a path and sending a word
// to what the walk reached are evaluation, and evaluation is `Resolver`.
//
// One way in and one way out. A value a run needs is an argument to it, the same
// as every other value here — there is no second tier of installed heads under a
// scope, so a name never resolves to something no declaration mentioned and the
// language has one answer to "where did this come from".
public struct Scope: Sendable {
    // MARK: - Property
    public private(set) var bindings: [String: Value]

    // Which names are variables, and what each one points at. The dictionary is
    // a value and the boxes are references, which is exactly the split scoping
    // needs — see `Variable`.
    private var variables: [String: Variable]

    // MARK: - Initializer
    public init(bindings: [String: Value] = [:]) {
        self.bindings = bindings
        self.variables = [:]
    }

    init(bindings: [String: Value], variables: [String: Variable]) {
        self.bindings = bindings
        self.variables = variables
    }

    // MARK: - Public
    // What a reference's first segment names here. Nil is absence — the name is
    // not in this environment at all.
    public func value(of head: String) -> Value? {
        if let variable = variables[head] { return variable.value }

        return bindings[head]
    }

    public func binding(_ id: String, to value: Value) -> Scope {
        var scope = self

        // A name introduced as a constant is a constant, even where a variable
        // of that name was visible — the inner name is a different name, and
        // the outer box must not be written through it.
        scope.variables[id] = nil
        scope.bindings[id] = value

        return scope
    }

    // Introduces a variable. The box is new, so a variable declared inside a
    // block shadows rather than writes an outer one of the same name, and dies
    // with the block that declared it.
    public func declaring(_ id: String, as value: Value) -> Scope {
        var scope = self

        scope.bindings[id] = nil
        scope.variables[id] = Variable(value)

        return scope
    }

    // Writes a variable declared earlier. Nothing about the scope changes —
    // the write lands in a box the enclosing bodies already hold, which is how
    // it outlives the block it was written in.
    //
    // A name that is not a variable here cannot reach this: the validator
    // proves every assignment names one before the program runs.
    // A write through a path: the head names the box, and the rest of the
    // path says where inside its value the new value goes. The box is read
    // once, rewritten, and stored once, so nothing observes the value halfway.
    public func assign(_ path: [PathSegment], to value: Value) throws {
        guard let head = path.head, let box = variables[head] else {
            throw ExecutionError(
                "'\(path.rendered)' writes a name that is not a variable here"
            )
        }

        guard path.count > 1 else {
            box.value = value
            return
        }

        box.value = try box.value.writing(value, at: Array(path.dropFirst()), under: path.rendered)
    }

    // The box under a name, where the name is a variable. Handing a box on is
    // how a call shares a variable with its callee.
    func box(of name: String) -> Variable? {
        variables[name]
    }

    // The same scope holding a box under a name — what a callee reads its
    // `inout` parameter through.
    func sharing(_ box: Variable, as name: String) -> Scope {
        var scope = self
        scope.bindings[name] = nil
        scope.variables[name] = box
        return scope
    }

    // MARK: - Private
}
