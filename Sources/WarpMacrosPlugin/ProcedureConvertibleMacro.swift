//
//  ProcedureConvertibleMacro.swift
//  WarpMacrosPlugin
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// `@ProcedureConvertible("App.step")` on a query, an effect or a computation
// that writes its work as a Swift function: the function's labeled parameters
// are the procedure's, its return type is what the procedure returns, and the
// arguments after the name are the rest of its `Signature`.
public struct ProcedureConvertibleMacro: ExtensionMacro {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            let name = arguments.first, name.label == nil
        else {
            throw MacroExpansionErrorMessage("@ProcedureConvertible takes the procedure's name first")
        }

        let kind = try NativeKind(of: declaration)
        let work = try kind.work(in: declaration)
        let access = Access(of: declaration).prefix
        let parameters = work.parameters
        let rest = arguments.dropFirst().map { argument in argument.trimmedDescription }
        let returns = work.returnType.map { returned in ["returns: returned(\(returned).self)"] } ?? []
        let signature = (["of: Self.self"] + returns + rest).joined(separator: ", ")

        let parameterSet = parameters.isEmpty
            ? "\(access)typealias Parameters = Warp.NoParameters"
            : """
            \(access)enum Parameters: Int, Warp.ParameterSet {
                \(parameters.map { parameter in "case `\(parameter.name)`" }.joined(separator: "\n"))

                \(access)var declared: Warp.Parameter {
                    func parameter<Argument: Warp.ValueRepresentable>(_ name: Warp.Name, _: Argument.Type) -> Warp.Parameter {
                        Warp.Parameter(name: name, type: Argument.type)
                    }

                    switch self {
                    \(parameters.map { parameter in "case .`\(parameter.name)`: return parameter(\"\(parameter.name)\", \(parameter.type).self)" }.joined(separator: "\n"))
                    }
                }
            }
            """

        let handed = parameters.map { parameter in
            let label = parameter.label.map { label in "\(label): " } ?? ""

            return "\(label)try read(\(kind.context)[.`\(parameter.name)`])"
        }
        let context = work.takesContext ? [(work.contextLabel.map { label in "\(label): " } ?? "") + kind.context] : []
        let call = "\(work.throws ? "try " : "")\(work.async ? "await " : "")\(kind.verb)("
            + (handed + context).joined(separator: ", ")
            + ")"
        let answer = work.returnType == nil
            ? "\(call)\n\nreturn .null"
            : "return try written(\(call))"

        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Warp.ProcedureConvertible {
                \(raw: parameterSet)

                \(raw: access)var name: Warp.Name { \(name.expression) }

                \(raw: access)var procedure: Warp.Procedure {
                    func returned<Returned: Warp.ValueRepresentable>(_: Returned.Type) -> Warp.TypeExpression { Returned.type }

                    return Warp.Procedure(signature: Warp.Signature(\(raw: signature)), implementation: self)
                }

                \(raw: access)\(raw: kind.entry) {
                    func read<Argument: Warp.ValueRepresentable>(_ value: Warp.Value) throws -> Argument { try Argument(value) }

                    func written<Returned: Warp.ValueRepresentable>(_ returned: Returned) throws -> Warp.Value { try returned.value }

                    \(raw: answer)
                }
            }
            """
        )

        return [extensionDecl]
    }

    // MARK: - Private
}
