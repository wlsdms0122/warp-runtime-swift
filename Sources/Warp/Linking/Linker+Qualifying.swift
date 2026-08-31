//
//  Linker+Qualifying.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

// Type and constraint names carry their module the way procedure names do, and
// a mention resolves by the same rule — `Linker.resolution`, the one function
// every namespace resolves through. The standard bundles write their shared
// vocabulary qualified (`std.Numeric`), so a document declaring a bare name of
// its own never quietly changes what `std.math` meant by it.
//
// Resolving is a rewrite, the same as it is for selectors. Every type
// expression a module carries — declared types, constraint members, signatures,
// and the signatures of closure literals buried in bodies and constants — is
// rewritten into qualified names, so the table the run reads is keyed by one
// spelling and never has to ask where a mention was written.
extension Linker {
    // A declaration's place together with where the caller put the module that
    // wrote it. The position is what tells two documents apart when neither was
    // read from anything, since a module a caller built has no identity and two
    // of them may declare into one namespace or into none.
    struct Declaration {
        let place: Place
        let origin: Int

        var spelled: String { place.document.spelled(at: origin) }
    }

    // The modules with every type and constraint mention resolved, together
    // with the two spaces gathered whole — gathered here and nowhere else, so
    // the uniqueness this pass refuses on is the same fact the tables are
    // built from. A mention nothing declares is left as written: the judgment
    // that refuses an undeclared name owns that refusal, and it says where
    // the mention lives.
    func qualified(_ modules: [Module]) throws -> (
        modules: [Module],
        types: [String: Declared<TypeExpression>],
        constraints: [String: Declared<[TypeExpression]>]
    ) {
        // Where each name was written, gathered here and carried with what it
        // holds. This is where both halves of the joining are in hand —
        // anywhere later has only the joined name, and taking it apart again is
        // a second copy of a rule that has to be right once.
        //
        // One table per space, and the table is what says a name is taken. A
        // set beside it saying the same thing is a second answer to one
        // question, and the two come apart exactly where it matters: a refusal
        // about a name declared twice is the one reader that needs the entry
        // the set had already accounted for.
        //
        // Each space is walked whole before the two are held against each
        // other, so what a link concludes cannot depend on the order the caller
        // happened to list the modules in.
        var typePlaces: [String: Declaration] = [:]
        var constraintPlaces: [String: Declaration] = [:]

        for (origin, module) in modules.enumerated() {
            for name in module.types.keys.sorted() {
                let qualified = module.qualified(name)
                let declaration = Declaration(place: .type(name, in: .of(module)), origin: origin)

                // Read before written. Written first, the entry that says what
                // this collides with is the one this call overwrote.
                if let first = typePlaces[qualified] {
                    throw LinkError(
                        "type '\(qualified)' is declared more than once in this link — by"
                            + " \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                typePlaces[qualified] = declaration
            }
        }

        for (origin, module) in modules.enumerated() {
            for name in module.constraints.keys.sorted() {
                let qualified = module.qualified(name)
                let declaration = Declaration(
                    place: .constraint(name, in: .of(module)),
                    origin: origin
                )

                if let declared = typePlaces[qualified] {
                    throw LinkError(
                        "'\(qualified)' is declared as both a type and a constraint in"
                            + " this link — as a type by \(declared.spelled) and as a"
                            + " constraint by \(declaration.spelled) — one name cannot"
                            + " stand for a shape and a membership at once",
                        at: declaration.place
                    )
                }

                if let first = constraintPlaces[qualified] {
                    throw LinkError(
                        "constraint '\(qualified)' is declared more than once in this"
                            + " link — by \(first.spelled) and \(declaration.spelled)",
                        at: declaration.place
                    )
                }

                constraintPlaces[qualified] = declaration
            }
        }

        let types = Set(typePlaces.keys)
        let constraints = Set(constraintPlaces.keys)

        // A shape and a membership are two questions, so a name is resolved in
        // the space its position asks in — a slot mentions types, a bound
        // mentions constraints, and one being unique in its own space is
        // enough.
        let renamed = try modules.map { module in
            // The module's own spellings, prepared once per module — a mention
            // is resolved per occurrence, and the occurrences are many.
            let ownedTypes = module.types.keys.map(module.qualified)
            let ownedConstraints = module.constraints.keys.map(module.qualified)

            return try module.renamed(
                types: { name in
                    try resolve(name, of: "type", owning: ownedTypes, among: types)
                },
                constraints: { name in
                    try resolve(
                        name,
                        of: "constraint",
                        owning: ownedConstraints,
                        among: constraints
                    )
                }
            )
        }

        // Uniqueness was refused above, so this only gathers — from the
        // renamed modules, whose keys and mentions are the spellings every
        // later reading uses.
        var declaredTypes: [String: Declared<TypeExpression>] = [:]
        var declaredConstraints: [String: Declared<[TypeExpression]>] = [:]

        for module in renamed {
            for (name, type) in module.types {
                // The place was gathered above, under the same joined name and
                // from the same declaration, so this cannot miss — and if the
                // two ever came apart, the crash says so where a `nil` place
                // would have gone out looking like a refusal with nowhere to be.
                declaredTypes[name] = Declared(type, at: typePlaces[name]!.place)
            }

            for (name, members) in module.constraints {
                declaredConstraints[name] = Declared(members, at: constraintPlaces[name]!.place)
            }
        }

        return (renamed, declaredTypes, declaredConstraints)
    }

    // The shared rule, with this surface's two failure sentences: a mention
    // nothing declares is left for the judgment that owns undeclared names,
    // and an ambiguous one refuses here — the candidates are all qualified
    // spellings (a bare one would have resolved exactly), so the instruction
    // can be followed.
    private func resolve(
        _ name: String,
        of kind: String,
        owning owned: [String],
        among declared: Set<String>
    ) throws -> String {
        switch Self.resolution(of: name, owned: owned, among: declared) {
        case let .resolved(qualified):
            return qualified

        case .unresolved:
            return name

        case let .ambiguous(candidates):
            throw LinkError(
                "\(kind) '\(name)' is declared by more than one module —"
                    + " \(candidates.joined(separator: ", ")) — a bare"
                    + " spelling cannot say which, so write the qualified name",
                // What is wrong is the mention, and the walk that reaches one
                // rewrites every type expression a module carries without
                // carrying where in the module it is. The document alone would
                // be an address that addresses nothing — a place is a thing a
                // front end walks into a line, and there is nothing here to
                // walk. The candidates are all in the sentence, which is what
                // there is to act on.
                at: nil
            )
        }
    }
}

// Named across the link. Reachable past this file because a refusal keyed by
// what the link calls a declaration has to be walked back to what the document
// calls it, and this is the joining that has to be undone.
extension Module {
    func qualified(_ name: String) -> String {
        self.name.map { module in "\(module).\(name)" } ?? name
    }
}

private extension Module {
    func renamed(
        types: (String) throws -> String,
        constraints rename: (String) throws -> String
    ) throws -> Module {
        // Everything this does not name is carried through, which is the point
        // of going by way of the copy: renaming rewrites what declarations are
        // called across the link and changes nothing else about the module.
        replacing(
            types: try self.types
                .reduce(into: [:]) { renamed, entry in
                    renamed[qualified(entry.key)] = try entry.value
                        .renamed(types: types, constraints: rename)
                },
            constraints: try self.constraints
                .reduce(into: [:]) { renamed, entry in
                    renamed[qualified(entry.key)] = try entry.value
                        .map { member in try member.renamed(types: types, constraints: rename) }
                },
            constants: try constants.mapValues { constant in
                try constant.renamed(types: types, constraints: rename)
            },
            procedures: try procedures.mapValues { procedure in
                try procedure.renamed(types: types, constraints: rename)
            }
        )
    }
}

private extension Procedure {
    func renamed(
        types: (String) throws -> String,
        constraints: (String) throws -> String
    ) throws -> Procedure {
        let implementation: Implementation

        switch self.implementation {
        case let .body(block):
            implementation = .body(try block.renamed(types: types, constraints: constraints))

        // Native code mentions no names a document declared.
        case .query, .effect:
            implementation = self.implementation
        }

        return Procedure(
            description: description,
            signature: try signature.renamed(types: types, constraints: constraints),
            implementation: implementation
        )
    }
}

private extension Signature {
    func renamed(
        types: (String) throws -> String,
        constraints: (String) throws -> String
    ) throws -> Signature {
        Signature(
            receiver: receiver,
            parameters: try parameters.mapValues { parameter in
                try parameter.renamed(types: types, constraints: constraints)
            },
            returns: try returns.map { returns in
                try returns.renamed(types: types, constraints: constraints)
            }
        )
    }
}

private extension Parameter {
    func renamed(
        types: (String) throws -> String,
        constraints: (String) throws -> String
    ) throws -> Parameter {
        Parameter(
            type: try type.map { type in
                try type.renamed(types: types, constraints: constraints)
            },
            oneOf: oneOf,
            default: `default`,
            hint: hint
        )
    }
}

private extension TypeExpression {
    func renamed(
        types: (String) throws -> String,
        constraints: (String) throws -> String
    ) throws -> TypeExpression {
        switch self {
        // A reading names a path in a body, not a name any module owns —
        // there is nothing in it to qualify.
        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged,
            .reading:
            return self

        case let .named(name):
            return .named(try types(name))

        case let .variable(name, bound):
            return .variable(name: name, constraint: try bound.map(constraints))

        case let .array(element):
            return .array(try element.renamed(types: types, constraints: constraints))

        case let .object(entry):
            return .object(try entry.renamed(types: types, constraints: constraints))

        case let .nullable(inner):
            return .nullable(try inner.renamed(types: types, constraints: constraints))

        case let .record(fields):
            return .record(
                try fields.mapValues { field in
                    try field.renamed(types: types, constraints: constraints)
                }
            )

        case let .procedure(signature, purity):
            return .procedure(
                try signature.map { signature in
                    try signature.renamed(types: types, constraints: constraints)
                },
                purity
            )
        }
    }
}

// The walk that finds every closure literal, because a closure carries a
// signature and a signature mentions names. Everything else is carried through
// unchanged.
private extension Block {
    func renamed(
        types: (String) throws -> String,
        constraints: (String) throws -> String
    ) throws -> Block {
        Block(
            body: try body.map { statement in
                try statement.renamed(types: types, constraints: constraints)
            },
            result: try result.map { result in
                try result.renamed(types: types, constraints: constraints)
            }
        )
    }
}

private extension Statement {
    func renamed(
        types: (String) throws -> String,
        constraints: (String) throws -> String
    ) throws -> Statement {
        Statement(
            id: id,
            binding: binding,
            expression: try expression.renamed(types: types, constraints: constraints)
        )
    }
}

private extension Expression {
    func renamed(
        types: (String) throws -> String,
        constraints rename: (String) throws -> String
    ) throws -> Expression {
        func renamed(_ inner: Expression) throws -> Expression {
            try inner.renamed(types: types, constraints: rename)
        }

        switch self {
        case .literal, .reference:
            return self

        case let .leave(leave):
            return .leave(
                Leave(
                    reach: leave.reach,
                    target: leave.target,
                    value: try leave.value.map(renamed)
                )
            )

        // A cast names a shape, and a shape may be a name a module declares
        // — so the spelling travels through the same renaming every declared
        // type does, or a qualified program would carry one that never
        // resolved.
        case let .cast(value, type, optional):
            return .cast(
                try renamed(value),
                as: try type.renamed(types: types, constraints: rename),
                optional: optional
            )

        case let .array(array):
            return .array(try array.map(renamed))

        case let .record(record):
            return .record(try record.mapValues(renamed))

        case let .closure(procedure):
            return .closure(try procedure.renamed(types: types, constraints: rename))

        case let .invoke(callee, arguments):
            return .invoke(try renamed(callee), arguments: try arguments.mapValues(renamed))

        case let .dispatch(dispatch):
            return .dispatch(
                Dispatch(
                    receiver: try dispatch.receiver.map(renamed),
                    selector: dispatch.selector,
                    arguments: try dispatch.arguments.mapValues(renamed)
                )
            )

        case let .block(block):
            return .block(try block.renamed(types: types, constraints: rename))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try renamed(condition),
                then: try then.map { statement in
                    try statement.renamed(types: types, constraints: rename)
                },
                else: try otherwise.map { arm in
                    try arm.map { statement in
                        try statement.renamed(types: types, constraints: rename)
                    }
                }
            )

        case let .loop(condition, body, round):
            return .loop(
                while: try renamed(condition),
                body: try body.renamed(types: types, constraints: rename),
                round: round
            )

        case let .iteration(material, body, element):
            return .iteration(
                over: try renamed(material),
                body: try body.map { statement in
                    try statement.renamed(types: types, constraints: rename)
                },
                element: element
            )

        case let .attempt(block, rescue, failure):
            return .attempt(
                try block.renamed(types: types, constraints: rename),
                rescue: try rescue.renamed(types: types, constraints: rename),
                failure: failure
            )
        }
    }
}
