//
//  NativeKind.swift
//  WarpMacrosPlugin
//

import SwiftSyntax
import SwiftSyntaxMacros

// Which of the three a native procedure adopts, which the type says by the
// protocol it names: what its work is called, what it is handed, and the
// entry the protocol asks for.
enum NativeKind {
    case effect
    case query
    case computation

    // MARK: - Property
    var verb: String {
        switch self {
        case .effect:
            "run"

        case .query:
            "evaluate"

        case .computation:
            "compute"
        }
    }

    // The name the entry hands its context under.
    var context: String {
        switch self {
        case .effect:
            "invocation"

        case .query:
            "question"

        case .computation:
            "arguments"
        }
    }

    var contextType: String {
        switch self {
        case .effect:
            "Invocation"

        case .query:
            "Question"

        case .computation:
            "Arguments"
        }
    }

    var entry: String {
        switch self {
        case .effect:
            "func run(_ invocation: Warp.Invocation<Self>) async throws -> Warp.Value"

        case .query:
            "func evaluate(_ question: Warp.Question<Self>) async throws -> Warp.Value"

        case .computation:
            "func compute(_ arguments: Warp.Arguments<Self>) throws -> Warp.Value"
        }
    }

    // MARK: - Initializer
    init(of declaration: some DeclGroupSyntax) throws {
        let adopted = declaration.inheritanceClause?.inheritedTypes.compactMap { inherited in
            TypeName(inherited.type).text
        } ?? []
        let kinds: [NativeKind] = [.effect, .query, .computation].filter { kind in adopted.contains(kind.name) }

        guard kinds.count == 1, let kind = kinds.first else {
            throw MacroExpansionErrorMessage(
                "@ProcedureConvertible goes on a type adopting one of Effect, Query and Computation"
            )
        }

        self = kind
    }

    // MARK: - Public
    // The function the type writes its work in: the one under the kind's verb
    // that is not the entry itself.
    func work(in declaration: some DeclGroupSyntax) throws -> Work {
        let functions = declaration.memberBlock.members.compactMap { member in member.decl.as(FunctionDeclSyntax.self) }
            .filter { function in function.name.text == verb }
            .map { function in Work(function, context: contextType) }
            .filter { work in !work.isEntry }

        guard functions.count == 1, let work = functions.first else {
            throw MacroExpansionErrorMessage("@ProcedureConvertible reads one function named '\(verb)' with labeled parameters")
        }

        return work
    }

    // MARK: - Private
    private var name: String {
        switch self {
        case .effect:
            "Effect"

        case .query:
            "Query"

        case .computation:
            "Computation"
        }
    }
}
