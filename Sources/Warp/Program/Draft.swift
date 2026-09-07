//
//  Draft.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a document declares, before anything has been held to the language's
// rules. A draft is not a module: it cannot be linked and cannot be run, and
// the only thing that takes one is the module's initializer, which is where the
// checking is.
//
// It exists because two questions are asked of one text and only one of them is
// about the program. What a document *is* (which is what telling one document
// from another is done on) is answered by writing it back out, and a document
// with a name nothing declares is still a document. So the writing takes a
// draft, and a text nobody can run still has a canonical form and an identity.
public struct Draft: Sendable {
    // MARK: - Property
    public let description: String?

    // What the document said it imports, and nil where it said nothing. A
    // module resolves this; here it is still only what was written.
    public let imports: Set<Name>?

    public let types: [Name: TypeExpression]
    public let constraints: [Name: [TypeExpression]]

    // Contracts this module declares: a name bound to the words a value must
    // answer to stand under it. Each word is a signature the implementing
    // declaration is held to, written without the receiver, which is the
    // implementing type itself.
    public let contracts: [Name: [Name: Signature]]

    public let constants: [Name: Expression]

    // Names bound to boxes the document's procedures share, each holding what
    // its expression settles to when a run starts. Declared like a constant
    // and read by the same spelling; unlike a constant, a body may write one.
    public let variables: [Name: Expression]

    public let procedures: [Name: Procedure]

    // MARK: - Initializer
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
        contracts: [Name: [Name: Signature]] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: Expression] = [:],
        procedures: [Name: Procedure]
    ) {
        self.description = description
        self.imports = imports
        self.types = types
        self.constraints = constraints
        self.contracts = contracts
        self.constants = constants
        self.variables = variables
        self.procedures = procedures
    }

    // The words this declares and does not itself declare a procedure for.
    //
    // Sent, not reached. A path reaches words too (`x.count` is one) but only
    // ones that answer without running, since that is the whole of what makes a
    // path safe to walk. So this is everything the program can do that touches
    // anything, and a caller reading it is reading the bounds of what it is
    // about to allow.
    public var sends: Set<Name> {
        // A constant is an expression, so it sends words like any other.
        // Missing them would understate what a program does.
        let held = constants.values.flatMap(\.buried)
            + variables.values.flatMap(\.buried)
            + procedures.values.flatMap { procedure in procedure.block?.buried ?? [] }

        // A native word's sends are its own declaration rather than something
        // read off a body, since a Swift body is not text this could read. A
        // list that missed them would understate what the module does, which
        // is the one thing this list may not do.
        let native = procedures.values.flatMap { procedure in
            procedure.implementation.nativeImports?.map(\.selector) ?? []
        }

        return held
            .reduce(into: Set(native)) { sent, expression in
                guard case let .call(call) = expression else { return }

                sent.insert(call.selector)
            }
            .subtracting(declaredWords)
    }

    // MARK: - Internal
    // The words this declares, by the spelling the link knows each one as. A
    // contract's word is one of them: the spelling a call writes to reach one
    // is the contract's name and the word's, and this document declared the
    // contract.
    var declaredWords: Set<Name> {
        Set(procedures.keys).union(
            contracts.flatMap { contract, words in
                words.keys.map { word in Name(normal: "\(contract.spelling).\(word.spelling)") }
            }
        )
    }

    // The shapes this declares. Types, constraints and contracts are one
    // space: a link refuses a name standing for a shape and a membership at
    // once.
    var declaredShapes: Set<Name> {
        Set(types.keys).union(constraints.keys).union(contracts.keys)
    }

    // The shapes this names and does not itself declare.
    //
    // Derived, where `sends` is written down. The list a document carries
    // exists so a caller can decide what it is about to allow before reading
    // any of it, and what confers that is words. A type name grants nothing,
    // so there is nothing for a document to disclose about the shapes it
    // declares against, and what a signature mentions is worked out here from
    // the module itself.
    var mentions: Set<Name> {
        var mentioned: Set<Name> = []

        for type in types.values {
            mentioned.formUnion(type.mentions)
        }

        for members in constraints.values {
            for member in members {
                mentioned.formUnion(member.mentions)
            }
        }

        for words in contracts.values {
            for signature in words.values {
                mentioned.formUnion(signature.mentions)
            }
        }

        for procedure in procedures.values {
            mentioned.formUnion(procedure.signature.mentions)

            guard let block = procedure.block else { continue }

            mentioned.formUnion(mentions(buried: block))
        }

        for held in Array(constants.values) + Array(variables.values) {
            mentioned.formUnion(mentions(buried: held))
        }

        return mentioned.subtracting(declaredShapes)
    }

    // MARK: - Private
    // The shapes named inside a body: what a local binding says it holds, what
    // a cast asks for, and what a closure literal's own signature writes. A
    // signature written inline is held to the same table the top level is, so
    // what it names is asked for the same way.
    private func mentions(buried held: some Burying) -> Set<Name> {
        held.walked(at: ()) { _, _ in () }
            .reduce(into: Set<Name>()) { mentioned, found in
                switch found.1 {
                case let .statement(statement):
                    guard let declared = statement.binding?.declared else { return }

                    mentioned.formUnion(declared.mentions)

                case let .expression(expression):
                    switch expression {
                    case let .cast(_, type, _):
                        mentioned.formUnion(type.mentions)

                    case let .closure(procedure):
                        mentioned.formUnion(procedure.signature.mentions)

                    default:
                        break
                    }
                }
            }
    }
}
