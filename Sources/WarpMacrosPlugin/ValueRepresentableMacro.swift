//
//  ValueRepresentableMacro.swift
//  WarpMacrosPlugin
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// `@ValueRepresentable("App.Point")` on a struct: the struct stands for the
// declared struct of that name, whose fields are its stored properties.
public struct ValueRepresentableMacro: ExtensionMacro {
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
        guard let structure = declaration.as(StructDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@ValueRepresentable stands a struct for a declared struct")
        }

        guard let name = node.arguments?.as(LabeledExprListSyntax.self)?.first?.expression else {
            throw MacroExpansionErrorMessage("@ValueRepresentable takes the name of the declared struct")
        }

        let access = Access(of: structure).prefix
        let fields = try StoredField.all(of: structure)
        let declared = fields.map { field in "\(field.literal): field(\(field.type).self)" }.joined(separator: ", ")
        let read = fields.map { field in "self.\(field.spelling) = try read(\(field.literal))" }
        let written = fields.map { field in "(name: \(field.literal), value: try written(\(field.spelling)))" }
            .joined(separator: ", ")

        // Swift types are named through `.self`, which takes every spelling a
        // type annotation has: `String?`, `[Int]`, `[String: Int]`.
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Warp.ValueRepresentable {
                \(raw: access)static var type: Warp.TypeExpression { .named(\(name)) }

                \(raw: access)static var declaration: Warp.TypeDeclaration? {
                    func field<Field: Warp.ValueRepresentable>(_: Field.Type) -> Warp.TypeExpression { Field.type }

                    return .struct([\(raw: declared.isEmpty ? ":" : declared)])
                }

                \(raw: access)init(_ value: Warp.Value) throws {
                    guard case let .struct(instance) = value, instance.name == \(name) else {
                        throw Warp.ValueRefused("\\(Self.type) is read, and \\(value.nominal) arrived")
                    }

                    func read<Field: Warp.ValueRepresentable>(_ name: Warp.Name) throws -> Field {
                        try Field(instance[name] ?? .null)
                    }

                    \(raw: read.joined(separator: "\n"))
                }

                \(raw: access)var value: Warp.Value {
                    get throws {
                        func written<Field: Warp.ValueRepresentable>(_ field: Field) throws -> Warp.Value { try field.value }

                        let fields: [(name: Warp.Name, value: Warp.Value)] = [\(raw: written)]

                        return try Warp.Value.holding(fields, named: \(name))
                    }
                }
            }
            """
        )

        return [extensionDecl]
    }

    // MARK: - Private
}
