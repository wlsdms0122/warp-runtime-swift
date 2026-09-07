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
        let held = walking

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
    // The words this declares, by the spelling the link knows each one as.
    // Each name appears once, since both halves come from keys.
    var declaredWords: Set<Name> {
        Set(procedures.keys).union(contractWords)
    }

    // The words a path could reach, as far as this document decides it. A
    // path sends to a receiver and reads an answer back, so a declaration
    // without a receiver, or answering `never`, or stating that it runs, is
    // reachable by no walk.
    //
    // The rest of the rule is the link's. Whether a written body answers
    // without running is what it calls, and whether the other things a
    // declaration asks for are required is read off the shapes. So this is
    // every candidate and never a verdict: a spelling here may still turn out
    // unreachable, and none that belongs is missing.
    //
    // A contract's word is not one. A path reaches a declaration, and the
    // spelling that reaches a contract's word is the contract's own.
    var walkableWords: Set<Name> {
        Set(
            procedures
                .filter { _, procedure in
                    guard procedure.implementation.isNativelyPure != false else { return false }

                    let signature = procedure.signature

                    guard let receiver = signature.receiver else { return false }

                    return signature.parameters[receiver] != nil && signature.returns != .never
                }
                .keys
        )
    }

    // The spellings a call writes to reach the words of a contract this
    // declares: the contract's name and the word's, with a dot between them.
    var contractWords: Set<Name> {
        Set(
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

    // The bare spellings a path in here steps to.
    //
    // A path reaches a word by its last segment alone, so what it needs is
    // spelled differently from what a call needs and is looked up in a
    // different table. `sends` does not hold these, and rightly: it discloses
    // what the program can touch, and a path reaches only words that answer
    // without running.
    //
    // Wider than the truth on purpose. Whether `user.count` steps to a field
    // or to a word is settled by the type the step stands on, which is a fact
    // of the link and not of this text, so every step that could be a word is
    // one here. A reader of this list may look for a word nobody needed; one
    // narrowed by guessing would miss a word somebody did.
    //
    // What this document declares is not taken out, unlike the other two. A
    // bare step is answered from every declaration in the link rather than
    // from the document holding the path, so a document declaring a word by
    // that spelling has not thereby answered its own step.
    var walks: Set<Name> {
        var walked: Set<Name> = []

        // The head names something in scope rather than a step onto it, so
        // walking a path is walking everything after its head. An index's own
        // path is read the same way the path holding it is, head and all, so
        // it is walked by this same rule rather than by a second one.
        func step(_ path: [PathSegment]) {
            for segment in path.dropFirst() {
                switch segment {
                case let .key(name, _), let .word(name, _):
                    walked.insert(name)

                case let .indexRef(inner, _):
                    step(inner)

                case .index:
                    break
                }
            }
        }

        for held in walking {
            guard case let .reference(path) = held else { continue }

            step(path)
        }

        return walked
    }

    // The shapes this names and does not itself declare.
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
    // Every expression this holds. A constant is an expression, so it sends
    // words and walks paths like any other, and a list that missed them would
    // understate what the document does.
    private var walking: [Expression] {
        Array(constants.values).flatMap(\.buried)
            + Array(variables.values).flatMap(\.buried)
            + procedures.values.flatMap { procedure in procedure.block?.buried ?? [] }
    }

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
