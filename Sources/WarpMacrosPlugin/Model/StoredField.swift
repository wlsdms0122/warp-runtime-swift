//
//  StoredField.swift
//  WarpMacrosPlugin
//

import SwiftSyntax
import SwiftSyntaxMacros

// A stored property of a struct, read as a field of the declared struct it
// stands for: the name the field is declared under, the way Swift spells the
// property, and the Swift type it is written as.
struct StoredField {
    // MARK: - Property
    let name: String
    let spelling: String
    let type: String

    // The field's name as the declaration writes it.
    var literal: String { "\"\(name)\"" }

    // MARK: - Initializer
    // MARK: - Public
    // The stored properties in the order they are written. A property with a
    // getter is computed, and a static one belongs to the type; one only
    // observed is stored. A stored property needs its type written, which is
    // the field's type.
    static func all(of structure: StructDeclSyntax) throws -> [StoredField] {
        try structure.memberBlock.members.flatMap { member -> [StoredField] in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                !variable.modifiers.contains(where: { modifier in modifier.name.tokenKind == .keyword(.static) })
            else {
                return []
            }

            return try variable.bindings.compactMap { binding in
                guard isStored(binding), let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    return nil
                }

                guard let annotation = binding.typeAnnotation else {
                    throw MacroExpansionErrorMessage(
                        "@ValueRepresentable reads a field's type from its property, and '\(identifier.identifier.text)' writes none"
                    )
                }

                return StoredField(
                    name: identifier.identifier.identifier?.name ?? identifier.identifier.text,
                    spelling: identifier.identifier.text,
                    type: annotation.type.trimmedDescription
                )
            }
        }
    }

    // MARK: - Private
    private static func isStored(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessors = binding.accessorBlock?.accessors else { return true }
        guard case let .accessors(list) = accessors else { return false }

        let observers: [Keyword] = [.willSet, .didSet]

        return list.allSatisfy { accessor in
            observers.contains { keyword in accessor.accessorSpecifier.tokenKind == .keyword(keyword) }
        }
    }
}
